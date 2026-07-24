//
//  NearbyStopsViewModel.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import OBAKitCore
@MainActor
class NearbyStopsViewModel: ObservableObject {
    @Published var stops: [OBAStop] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationStatus: String = OBALoc("nearby_stops.getting_location", value: "Getting location...", comment: "Status: getting location")
    @Published var routeSummaryByStopID: [OBAStopID: String] = [:]
    
    private let apiClientProvider: () -> OBAAPIClient
    private let locationProvider: () -> CLLocation
    private var cancellables = Set<AnyCancellable>()
    
    init(apiClientProvider: @escaping () -> OBAAPIClient, locationProvider: @escaping () -> CLLocation) {
        self.apiClientProvider = apiClientProvider
        self.locationProvider = locationProvider
        
        // Listen for location updates
        NotificationCenter.default.publisher(for: .LocationUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadNearbyStops()
                }
            }
            .store(in: &cancellables)
        
        // Initial load
        Task {
            await loadNearbyStops()
        }
    }
    
    func loadNearbyStops() async {
        let location = locationProvider()
        let apiClient = apiClientProvider()
        
        isLoading = true
        errorMessage = nil
        locationStatus = OBALoc("nearby_stops.loading_stops", value: "Loading stops...", comment: "Status: loading stops")
        
        defer { isLoading = false }

        do {
            var locationToUse = location
            var fetched = try await apiClient.fetchNearbyStops(
                latitude: locationToUse.coordinate.latitude,
                longitude: locationToUse.coordinate.longitude,
                radius: 2500.0
            )

            // If 0 stops found at location (e.g. simulator default in Cupertino), fallback to active region center
            if fetched.stops.isEmpty, let regionCenter = WatchAppState.shared.activeRegionCenter {
                locationToUse = CLLocation(latitude: regionCenter.latitude, longitude: regionCenter.longitude)
                fetched = try await apiClient.fetchNearbyStops(
                    latitude: locationToUse.coordinate.latitude,
                    longitude: locationToUse.coordinate.longitude,
                    radius: 5000.0
                )
            }

            routeSummaryByStopID = fetched.stopIDToRouteNames
            stops = fetched.stops
                .sorted { stop1, stop2 in
                    let loc1 = CLLocation(latitude: stop1.latitude, longitude: stop1.longitude)
                    let loc2 = CLLocation(latitude: stop2.latitude, longitude: stop2.longitude)
                    let distance1 = loc1.distance(from: locationToUse)
                    let distance2 = loc2.distance(from: locationToUse)
                    return distance1 < distance2
                }
            
            if stops.isEmpty {
                locationStatus = OBALoc("nearby_stops.no_stops", value: "No stops found near this location", comment: "Status: no stops")
            } else {
                locationStatus = String(format: OBALoc("nearby_stops.count_fmt", value: "%d stops nearby", comment: "Stops count label"), stops.count)
            }
        } catch {
            errorMessage = error.watchOSUserFacingMessage
            locationStatus = OBALoc("nearby_stops.error_loading_stops", value: "Error loading stops", comment: "Status: error loading stops")
        }
    }
}
