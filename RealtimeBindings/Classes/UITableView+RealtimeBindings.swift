//
// Created by Christoph Muck on 07/10/2017.
//

import RxSwift
import RxCocoa
import RxDataSources

typealias RxIdentifiableType = RxDataSources.IdentifiableType

public protocol IdentifiableType {

    var id: String { get }
}

extension UITableView {

    public typealias ViewModel = ViewModelType & IdentifiableType & Equatable

    public func observeChangesFrom<T, V:ViewModel>(
            dataSource: RealtimeDataSource<T>,
            sortBy: ((T, T) -> Bool)? = nil,
            cellFactory: @escaping (UITableView, Int, V) -> UITableViewCell
    ) -> Disposable where V.T == T {

        let compositeDisposable = CompositeDisposable()
        let data = dataSource.changes(sortBy: sortBy)
                .map { items -> [SectionOfCustomData<RxDataIdentifiableDelegate<V>>] in
                    let viewModels = items.map { element -> RxDataIdentifiableDelegate<V> in
                        let viewModel: V = UITableView.createViewModel(from: element,
                                sendDataFunc: dataSource.saveElement,
                                disposedBy: compositeDisposable)
                        return RxDataIdentifiableDelegate(element: viewModel)
                    }
                    return [SectionOfCustomData(items: viewModels)]
                }

        let dataSource = RxTableViewSectionedAnimatedDataSource<SectionOfCustomData<RxDataIdentifiableDelegate<V>>>(configureCell: {
            (_, tableView, indexPath, elementDelegate: RxDataIdentifiableDelegate<V>) -> UITableViewCell in
            return cellFactory(tableView, indexPath.row, elementDelegate.element)
        }, canEditRowAtIndexPath: { _, _ in true })


        let disposable = data.bind(to: self.rx.items(dataSource: dataSource))
        _ = compositeDisposable.insert(disposable)

        return compositeDisposable
    }
}

private extension UITableView {

    class func createViewModel<T:Encodable, V:ViewModel>(
            from element: T,
            sendDataFunc: @escaping (T) -> Single<Void>,
            disposedBy: CompositeDisposable
    ) -> V where V.T == T {
        let viewModel = V.init(fromElement: element)

        let disposable = viewModel.updatedElements
                .flatMapLatest { sendDataFunc($0).catchError { _ in Single.just(()) } }
                .subscribe()
        _ = disposedBy.insert(disposable)

        return viewModel
    }
}

struct RxDataIdentifiableDelegate<T:IdentifiableType & Equatable>: RxIdentifiableType, Equatable {

    let element: T

    var identity: String {
        return element.id
    }

    static func ==(lhs: RxDataIdentifiableDelegate<T>, rhs: RxDataIdentifiableDelegate<T>) -> Bool {
        return lhs.element == rhs.element
    }
}

struct SectionOfCustomData<I:RxIdentifiableType & Equatable> {
    var items: [I]
}

extension SectionOfCustomData: AnimatableSectionModelType {

    init(original: SectionOfCustomData, items: [I]) {
        self = original
        self.items = items
    }
}

extension SectionOfCustomData: RxIdentifiableType {
    var identity: Int {
        return 1
    }
}

public enum HttpError: Error {
    case failure(body: String, statusCode: Int)
}

enum ChangeEvent: String, Codable {
    case INITIAL, CREATED, DELETED, UPDATED
}

struct Change<T:Decodable>: Decodable {
    let value: T
    let event: ChangeEvent
}

public protocol ViewModelType {

    associatedtype T

    init(fromElement: T)

    var updatedElements: Observable<T> { get }
}
