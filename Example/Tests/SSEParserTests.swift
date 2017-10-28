// https://github.com/Quick/Quick

import Quick
import Nimble
import RealtimeBindings
import RxBlocking

class SSEParserTests: QuickSpec {
    override func spec() {
        describe("SSE Parser Tests") {

            var sse: SSEParser!

            beforeEach {
                sse = SSEParser()
            }

            func sendDataAndGetResponse(_ strings: [String]) -> [String] {
                let replay = sse.replayAll()
                _ = replay.connect()
                strings.forEach {
                    sse.on(data: $0.data(using: .utf8)!)
                }
                sse.onCompleted()
                return try! replay.toBlocking().toArray()
            }

            it("1") {
                let realData = "{\"irgendwas\"}"
                let testInput = "data:\(realData)\n\n"
                let arr = sendDataAndGetResponse([testInput])
                expect(arr).to(equal([realData]))
            }

            it("2") {
                let realData = "{\"irgendwas\"}"
                let testInput = ["data:", realData, "\n\n"]
                let arr = sendDataAndGetResponse(testInput)
                expect(arr).to(equal([realData]))
            }

            it("3") {
                let realData = "{\"irgendwas\"}"
                let testInput = ["data:\(realData)\n\ndata:\(realData)\n\n"]
                let arr = sendDataAndGetResponse(testInput)
                expect(arr).to(equal([realData, realData]))
            }

            it("4") {
                let realData = "{\"irgendwas\"}"
                let testInput = ["data:\(realData)\n\ndata:", "\(realData)\n\n"]
                let arr = sendDataAndGetResponse(testInput)
                expect(arr).to(equal([realData, realData]))
            }

            it("5") {
                let realData = "{\"irgendwas\"}"
                let testInput = ["data:", "\(realData)\n\ndata:\(realData)\n\n"]
                let arr = sendDataAndGetResponse(testInput)
                expect(arr).to(equal([realData, realData]))
            }

            it("6") {
                let realData = "{\"irgendwas\"}"
                let testInput = ["data:", "\(realData)\n\ndata:\(realData)\n\ndata:\n"]
                let arr = sendDataAndGetResponse(testInput)
                expect(arr).to(equal([realData, realData]))
            }
        }
    }
}

