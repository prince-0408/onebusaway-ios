//
//  StopsOperationTest.swift
//  OBANetworkingKitTests
//
//  Created by Aaron Brethorst on 10/4/18.
//  Copyright © 2018 OneBusAway. All rights reserved.
//

import XCTest
import Nimble
import OHHTTPStubs
import CoreLocation
import MapKit
@testable import OBANetworkingKit

class StopsOperationTest: XCTestCase, OperationTest {
    let defaultCoordinate = CLLocationCoordinate2D(latitude: 47.624, longitude: -122.32)

    override func tearDown() {
        super.tearDown()
        OHHTTPStubs.removeAllStubs()
    }

    // MARK: - Stops Near Coordinate

    func testRetrievingStopsNearCoordinate() {
        let expectedParams = ["lat": "47.624", "lon": "-122.32"]

        stub(condition: isHost(self.host) &&
            isPath(StopsOperation.apiPath) &&
            containsQueryParams(expectedParams)) { _ in
                return self.JSONFile(named: "stops_for_location_seattle.json")
        }

        waitUntil { done in
            self.builder.getStops(coordinate: self.defaultCoordinate) { op in
                expect(op.entries?.first).toNot(beNil())
                done()
            }
        }
    }

    // MARK: - Stops in Circular Region

    func testRadiusIsClampedAt15000() {
        let region = CLCircularRegion(center: defaultCoordinate, radius: 30000, identifier: "ident")
        let url = StopsOperation.buildURL(circularRegion: region, query: "query!", baseURL: baseURL, defaultQueryItems: [])
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        let lat = components?.queryItemValueMatching(name: "lat")
        let lon = components?.queryItemValueMatching(name: "lon")
        let query = components?.queryItemValueMatching(name: "query")
        let radius = components?.queryItemValueMatching(name: "radius")
        expect(lat).to(equal("47.624"))
        expect(lon).to(equal("-122.32"))
        expect(query).to(equal("query!"))
        expect(radius).to(equal("15000"))
    }

    // MARK: - Stops in Coordinate Region

    func testRetrievingStopsInACoordinateRegions() {
        let coordinate = CLLocationCoordinate2D(latitude: 47.6230999, longitude: -122.3132122)
        let span = MKCoordinateSpan(latitudeDelta: 0.0015, longitudeDelta: 0.0015)
        let region = MKCoordinateRegion(center: coordinate, span: span)

        let expectedParams = [
            "lat": "47.6230999",
            "lon": "-122.3132122",
            "latSpan": "0.0015",
            "lonSpan": "0.0015"
        ]

        stub(condition: isHost(self.host) && isPath(StopsOperation.apiPath) && containsQueryParams(expectedParams)) { _ in
            return self.JSONFile(named: "stops_for_location_seattle_span.json")
        }

        waitUntil { done in
            self.builder.getStops(region: region) { op in
                expect(op.entries?.count).to(equal(1))
                done()
            }
        }
    }
}
