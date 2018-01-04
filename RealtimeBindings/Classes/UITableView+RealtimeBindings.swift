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

    public func observeChangesFrom<T, V: ViewModel>(
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

        let tableViewDataSource = RxTableViewSectionedAnimatedDataSource<SectionOfCustomData<RxDataIdentifiableDelegate<V>>>(configureCell: {
            (_, tableView, indexPath, elementDelegate: RxDataIdentifiableDelegate<V>) -> UITableViewCell in
            return cellFactory(tableView, indexPath.row, elementDelegate.element)
        }, canEditRowAtIndexPath: { _, _ in true })


        var disposable: Disposable

        disposable = data.bind(to: self.rx.items(dataSource: tableViewDataSource))
        _ = compositeDisposable.insert(disposable)

        disposable = self.rx.itemDeleted.asDriver().flatMapLatest { indexPath -> Driver<Void> in
            let itemToDelete = tableViewDataSource[indexPath]
            let id = itemToDelete.identity
            return dataSource.deleteElement(withId: id).debug().asDriver(onErrorJustReturn: ())
        }.drive()
        _ = compositeDisposable.insert(disposable)

        return compositeDisposable
    }
}

private extension UITableView {

    class func createViewModel<T: Codable, V: ViewModel>(
            from element: T,
            sendDataFunc: @escaping (T) -> Single<Void>,
            disposedBy: CompositeDisposable
    ) -> V where V.T == T {
        let viewModel = V.init(fromElement: element)

        let disposable = UITableView.updatedElements(of: viewModel)
                .flatMapLatest { element -> Single<Void> in
                    return sendDataFunc(element)
                }
                .catchError { error in
                    print(error)
                    return Observable.just(())
                }
                .subscribe()
        _ = disposedBy.insert(disposable)
        return viewModel
    }

    class func updatedElements<T: Decodable, V: ViewModelType>(
            of model: V
    ) -> Observable<T> {
        let mirror = Mirror(reflecting: model)
        var observables = [Observable<(String, Any)>]()
        mirror.children.forEach { child in
            let value = child.value
            let o: Observable<Any>
            switch (value) {
            case let v as AnyTypeObservableConvertible: o = v.asAnyObservable()
            default: o = Observable.never().startWith("")
            }
            observables.append(
                    o.withLatestFrom(Observable.just(child.label!)) {
                        return ($1, $0)
                    }
            )
        }

        return Observable.combineLatest(observables)
                .skip(1)
                .map { values in
                    var dict: [String: Any] = [:]
                    values.forEach { dict[parseLabel(from: $0.0)] = $0.1 }
                    let decoder = MapDecoder()
                    return try decoder.decode(T.self, from: dict)
                }
    }
}

public func parseLabel(from: String) -> String {
    let suffix = "Property"
    if from.hasSuffix(suffix) {
        let suffixStart = from.index(from.endIndex, offsetBy: -1 * suffix.count)
        return String(from.prefix(upTo: suffixStart))
    }
    return from
}

struct RxDataIdentifiableDelegate<T: IdentifiableType & Equatable>: RxIdentifiableType, Equatable {

    let element: T

    var identity: String {
        return element.id
    }

    static func ==(lhs: RxDataIdentifiableDelegate<T>, rhs: RxDataIdentifiableDelegate<T>) -> Bool {
        return lhs.element == rhs.element
    }
}

struct SectionOfCustomData<I: RxIdentifiableType & Equatable> {
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

struct Change<T: Decodable>: Decodable {
    let value: T
    let event: ChangeEvent
}

public protocol ViewModelType {

    associatedtype T

    init(fromElement: T)
}

public protocol AnyTypeObservableConvertible {
    func asAnyObservable() -> Observable<Any>
}

extension Variable: AnyTypeObservableConvertible {
    public func asAnyObservable() -> Observable<Any> {
        return self.asObservable().map { $0 as Any }
    }
}

extension Observable: AnyTypeObservableConvertible {
    public func asAnyObservable() -> Observable<Any> {
        return self.map { $0 as Any }
    }
}

extension Driver: AnyTypeObservableConvertible {
    public func asAnyObservable() -> Observable<Any> {
        return self.asObservable().map { $0 as Any }
    }
}
