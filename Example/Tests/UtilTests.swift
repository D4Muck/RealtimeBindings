//
//  UtilTests.swift
//  RealtimeBindings
//
//  Created by Christoph Muck on 29/10/2017.
//  Copyright © 2017 CocoaPods. All rights reserved.
//


import Quick
import Nimble
import RealtimeBindings

class UtilTestsSpec: QuickSpec {
    override func spec() {
        describe("parse label test") {

            it("works") {
                let label = parseLabel(from: "idProperty")
                expect(label) == "id"
            }
        }
    }
}
