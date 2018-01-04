//
// Created by Christoph Muck on 28/10/2017.
//

import Foundation
import RxSwift

public typealias Item = Codable & IdentifiableType

public class RealtimeDataSource<T: Item> {

    let url: String

    public init(url: String) {
        self.url = url
    }

    func changes(
            sortBy: ((T, T) -> Bool)? = nil
    ) -> Observable<[T]> {
        return SSEURLSession.instance.request(url: url + "/changes")
                .do(onNext: { print($0) })
                .map { (str: String) -> Change<T> in
                    return try! JSONDecoder().decode(Change<T>.self, from: str.data(using: .utf8)!)
                }
                .scan([]) { (arr: [T], element: Change<T>) -> [T] in

                    var elements = arr
                    let value = element.value

                    switch element.event {
                    case .CREATED:
                        elements.append(value)
                    case .INITIAL:
                        elements.append(value)
                    case .DELETED:
                        elements = elements.filter {
                            $0.id != element.value.id
                        }

                    case .UPDATED:
                        elements = elements.map {
                            if ($0.id == element.value.id) {
                                return value
                            } else {
                                return $0
                            }
                        }
                    }
                    return elements
                }
                .map { arr -> [T] in
                    guard let sortBy = sortBy else { return arr }
                    return arr.sorted(by: sortBy)
                }
    }

}

extension RealtimeDataSource {

    public func saveElement(_ value: T) -> Single<Void> {
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(value)
        } catch {
            return Single.error(error)
        }

        var request = URLRequest(url: URL(string: url)!)
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

    public func deleteElement(withId id: String) -> Single<Void> {
        var request = URLRequest(url: URL(string: url + "/" + id)!)
        request.httpMethod = "DELETE"

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

    public func deleteAllElements() -> Single<Void> {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "DELETE"

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
}
