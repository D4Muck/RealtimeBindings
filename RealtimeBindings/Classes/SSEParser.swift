//
// Created by Christoph Muck on 01/10/2017.
//

import Foundation
import RxSwift

public class SSEParser: ObservableType {

    let subject = PublishSubject<String>()

    public init() {
    }

    public typealias E = String

    private var buffer = Data()

    public func subscribe<O:ObserverType>(_ observer: O) -> Disposable where O.E == E {
        return subject.subscribe(observer)
    }

    public func onCompleted() {
        subject.onCompleted()
    }

    public func onError(_ error: Error) {
        subject.onError(error)
    }

    private func onNext(value: String) {
        subject.onNext(value)
    }

    public func on(data: Data) {
        buffer.append(data)
        parseDataAndInformObservers()
    }

    func parseDataAndInformObservers() {
        let str = String(data: buffer, encoding: .utf8)!
        var components = str.components(separatedBy: "\n\n")

        let rest = components.popLast()

        if let tmp = rest?.data(using: .utf8) {
            buffer = tmp
        } else {
            buffer = Data()
        }

        components.map {
            $0.replacingOccurrences(of: "data:", with: "")
        }.forEach {
            self.onNext(value: $0)
        }

    }
}
