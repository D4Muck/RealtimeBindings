//
// Created by Christoph Muck on 01/10/2017.
//

import Foundation
import RxSwift

public class SSEParser: ObservableType {

    public init() {
    }

    public typealias E = String

    private var observers: [AnyObserver<String>] = []

    private var buffer = Data()

    public func subscribe<O:ObserverType>(_ observer: O) -> Disposable where O.E == E {
        let anyObserver = observer.asObserver()
        observers.append(anyObserver)
        return Disposables.create()
    }

    public func onComplete() {
        observers.forEach {
            $0.onCompleted()
        }
    }

    public func onError(_ error:Error) {
        observers.forEach {
            $0.onError(error)
        }
    }
    
    private func onNext(value: String) {
        observers.forEach {
            $0.onNext(value)
        }
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
