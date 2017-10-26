//
// Created by Christoph Muck on 07/10/2017.
//

import RxSwift
import RxCocoa
import RxDataSources

extension UITableView {

    public typealias Item = Codable & IdentifiableType
    public typealias ViewModel = ViewModelType & IdentifiableType & Equatable

    public func observeChangesFrom<T:Item, V:ViewModel>(
            url: String,
            sortBy: ((V, V) -> Bool)? = nil,
            cellFactory: @escaping (UITableView, Int, V) -> UITableViewCell
    ) -> Disposable where V.T == T {

        let compositeDisposable = CompositeDisposable()

        let data = SSEURLSession.instance.request(url: url)
                .do(onNext: { print($0) })
                .map { (str: String) -> Change<T> in
                    return try! JSONDecoder().decode(Change<T>.self, from: str.data(using: .utf8)!)
                }
                .scan([]) { (arr: [V], element: Change<T>) -> [V] in

                    var elements = arr

                    let clazz = UITableView.self

                    switch element.event {
                    case .CREATED:
                        elements.append(clazz.createViewModel(from: element, disposedBy: compositeDisposable))
                    case .INITIAL:
                        elements.append(clazz.createViewModel(from: element, disposedBy: compositeDisposable))

                    case .DELETED:
                        elements = elements.filter {
                            $0.identity.hashValue != element.value.identity.hashValue
                        }

                    case .UPDATED:
                        elements = elements.map {
                            if ($0.identity.hashValue == element.value.identity.hashValue) {
                                return clazz.createViewModel(from: element, disposedBy: compositeDisposable)
                            } else {
                                return $0
                            }
                        }
                    }
                    return elements
                }
                .map { arr -> [V] in
                    guard let sortBy = sortBy else { return arr }
                    return arr.sorted(by: sortBy)
                }
                .map { [SectionOfCustomData(items: $0)] }

        let dataSource = RxTableViewSectionedAnimatedDataSource<SectionOfCustomData<V>>(configureCell: {
            (_, tableView, indexPath, element: V) -> UITableViewCell in
            return cellFactory(tableView, indexPath.row, element)
        })

        let disposable = data.bind(to: self.rx.items(dataSource: dataSource))
        _ = compositeDisposable.insert(disposable)
        return compositeDisposable
    }

    private static func createViewModel<T:Encodable, V:ViewModel>(from element: Change<T>, disposedBy: CompositeDisposable) -> V where V.T == T {
        let viewModel = V.init(fromElement: element.value)

        let disposable = viewModel.updatedElements.debug()
                .flatMapLatest {
                    sendDataToServer(value: $0).debug().catchError { _ in Single.just(()) }
                }
                .subscribe()
        _ = disposedBy.insert(disposable)

        return viewModel
    }
}

struct SectionOfCustomData<I:IdentifiableType & Equatable> {
    var items: [I]
}

extension SectionOfCustomData: AnimatableSectionModelType {

    init(original: SectionOfCustomData, items: [I]) {
        self = original
        self.items = items
    }
}

extension SectionOfCustomData: IdentifiableType {
    var identity: Int {
        return 1
    }
}

func sendDataToServer<T:Encodable>(value: T) -> Single<Void> {
    let encoded: Data
    do {
        encoded = try JSONEncoder().encode(value)
    } catch {
        return Single.error(error)
    }

    var request = URLRequest(url: URL(string: "http://localhost:8081/shoppingItem")!)
    request.httpBody = encoded
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    return Single.create { emitter in
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                emitter(.error(error))
                return
            }

            let response = response as! HTTPURLResponse

            if 200...299 ~= response.statusCode {
                emitter(.success(()))
            } else {

                var body: String = ""

                if let data = data {
                    body = String(data: data, encoding: .utf8) ?? ""
                }

                emitter(.error(HttpError.failure(body: body, statusCode: response.statusCode)))
            }
        }
        dataTask.resume()
        return Disposables.create { dataTask.cancel() }
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

public protocol Identifyable {
    var identifier: String { get }
}