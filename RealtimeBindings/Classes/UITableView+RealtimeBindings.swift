//
// Created by Christoph Muck on 07/10/2017.
//

import RxSwift
import RxCocoa

extension UITableView {

    public typealias Item = Codable & Identifyable
    public typealias ViewModel = ViewModelType & Identifyable

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
                .scan([]) { (arr: [V], elem: Change<T>) -> [V] in

                    var mutable = arr

                    let clazz = UITableView.self

                    switch elem.event {
                    case .CREATED:
                        mutable.append(clazz.createViewModel(from: elem, disposedBy: compositeDisposable))
                    case .INITIAL:
                        mutable.append(clazz.createViewModel(from: elem, disposedBy: compositeDisposable))

                    case .DELETED:
                        mutable = mutable.filter {
                            $0.identifier != elem.value.identifier
                        }

                    case .UPDATED:
                        mutable = mutable.map {
                            if ($0.identifier == elem.value.identifier) {
                                return clazz.createViewModel(from: elem, disposedBy: compositeDisposable)
                            } else {
                                return $0
                            }
                        }
                    }
                    return mutable
                }
                .map { arr -> [V] in
                    guard let sortBy = sortBy else { return arr }
                    return arr.sorted(by: sortBy)
                }
        let disposable = data.bind(to: self.rx.items, curriedArgument: cellFactory)
        _ = compositeDisposable.insert(disposable)
        return compositeDisposable
    }

    private static func createViewModel<T:Encodable, V:ViewModel>(from element: Change<T>, disposedBy: CompositeDisposable) -> V where V.T == T {
        let viewModel = V.init(fromElement: element.value)

        let disposable = viewModel.updatedElements.debug()
                .flatMapLatest{
                    sendDataToServer(value: $0)
                }
                .debug()
                .subscribe()
        _ = disposedBy.insert(disposable)

        return viewModel
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