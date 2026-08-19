//
//  ClosestDeparturesViewModel.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 19/08/26.
//

import Foundation
import SwiftUI
import CoreLocation
import OBAKitCore

@MainActor
final class ClosestDeparturesViewModel: ObservableObject {
    @Published var closestStop: OBAStop?
    @Published var upcomingArrivals: [OBAArrival] = []
    @Published var isLoading = false
    @Published var isArrivalsLoading = false
    @Published var errorMessage: String?

    var topArrivals: [OBAArrival] {
        Array(upcomingArrivals.prefix(3))
    }

    func loadClosestStopAndArrivals() async {
        let apiClient = WatchAppState.shared.apiClient
        let location = WatchAppState.shared.effectiveLocation

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let nearbyStopsResult = try await apiClient.fetchNearbyStops(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 1500.0
            )

            guard let firstStop = nearbyStopsResult.stops.first else {
                closestStop = nil
                upcomingArrivals = []
                return
            }

            closestStop = firstStop
            await loadArrivals(for: firstStop.id, apiClient: apiClient)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadArrivals(for stopID: OBAStopID, apiClient: OBAAPIClient) async {
        isArrivalsLoading = true
        defer { isArrivalsLoading = false }

        do {
            let payload = try await apiClient.fetchArrivals(for: stopID)
            let prefs = StopPreferencesStore.shared.preferences(for: stopID)
            
            let unhidden = payload.arrivals.filter { arrival in
                let routeID = arrival.routeID ?? arrival.routeShortName ?? ""
                return !prefs.isRouteIDHidden(routeID)
            }
            
            // Sort by earliest arrival time
            upcomingArrivals = unhidden.sorted {
                ($0.arrivalTime ?? Date.distantFuture) < ($1.arrivalTime ?? Date.distantFuture)
            }
        } catch {
            upcomingArrivals = []
        }
    }
}
