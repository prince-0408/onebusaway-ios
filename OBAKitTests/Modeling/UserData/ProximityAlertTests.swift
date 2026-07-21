//
//  ProximityAlertTests.swift
//  OBAKitTests
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import XCTest
import Nimble
import CoreLocation
@testable import OBAKit
@testable import OBAKitCore

// swiftlint:disable force_try
#if false
class ProximityAlertTests: OBATestCase {
    var stop: Stop!

    override func setUp() async throws {
        try await super.setUp()
        stop = try! Fixtures.loadSomeStops().first!
    }

    func test_init_setsPropertiesFromStop() {
        let alert = ProximityAlert(stop: stop)

        expect(alert.stopID) == stop.id
        expect(alert.stopName) == stop.name
        expect(alert.latitude) == stop.location.coordinate.latitude
        expect(alert.longitude) == stop.location.coordinate.longitude
        expect(alert.radiusMeters) == 200.0
        expect(alert.id).toNot(beNil())
        expect(alert.createdAt).toNot(beNil())
    }
}
#endif
