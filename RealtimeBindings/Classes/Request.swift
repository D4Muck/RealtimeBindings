//
//  Request.swift
//  RealtimeBindings
//
//  Created by Christoph Muck on 01/10/2017.
//

import Foundation
import RxSwift

public class SSEURLSession: NSObject {

    public static let instance = SSEURLSession()

    private var parsers: [URLSessionDataTask: SSEParser] = [:]

    public func request(url: String) -> Observable<String> {
        return Observable.deferred { [weak self] in
            return self?.createDataTaskAndParser(url: url) ?? Observable.error(RealtimeBindingsError.SSEURLSessionDisposed)
        }
    }

    private func createDataTaskAndParser(url: String) -> Observable<String> {
        var r = URLRequest(url: URL(string: url)!)
        r.httpMethod = "GET"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval.infinity

        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let dataTask: URLSessionDataTask = session.dataTask(with: r)
        let parser = SSEParser()

        self.parsers[dataTask] = parser
        dataTask.resume()
        return parser.asObservable()
    }
}

enum RealtimeBindingsError: Error {
    case SSEURLSessionDisposed
}

extension SSEURLSession: URLSessionDataDelegate {

    //
    //    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    //        let f = response as? HTTPURLResponse
    //        print("1")
    //        completionHandler(.allow)
    //    }

    //    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
    //        print("2")
    //    }

    //    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask) {
    //        print("3")
    //    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let dataTask = task as? URLSessionDataTask
        let parser: SSEParser?
        if let notNilTask = dataTask {
            parser = parsers[notNilTask]
        } else {
            parser = nil
        }
        if let e = error {
            print("finished with error")
            print(e)
            parser?.onError(e)
        } else {
            print("Everything is dandy!")
            parser?.onComplete()
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print(parsers[dataTask])
        print(parsers)
        print("Got data")
        parsers[dataTask]?.on(data: data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        print("4")
        //        completionHandler(.none)
    }
}
