//
//  StopArrivalsViewModel.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import SwiftUI
import Combine
import OBAKitCore

@MainActor
class StopArrivalsViewModel: ObservableObject {
    @Published var arrivals: [OBAArrival] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var routes: [OBARoute] = []
    @Published var stopName: String?
    
    private let apiClientProvider: () -> OBAAPIClient
    private let stopID: OBAStopID
    private var refreshTask: Task<Void, Never>?
    
    init(apiClientProvider: @escaping () -> OBAAPIClient, stopID: OBAStopID) {
        print("[WatchOS Debug] StopArrivalsViewModel.init called for stopID: \(stopID)")
        self.apiClientProvider = apiClientProvider
        self.stopID = stopID
        
        // Load arrivals asynchronously
        Task { @MainActor in
            await loadArrivals()
            await loadRoutes()
        }
        
        // Auto-refresh every 30 seconds
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                } catch {
                    break
                }
                await self?.loadArrivals()
            }
        }
    }
    
    func cancelRefresh() {
        print("[WatchOS Debug] StopArrivalsViewModel.cancelRefresh called for stopID: \(stopID)")
        refreshTask?.cancel()
        refreshTask = nil
    }

    deinit {
        print("[WatchOS Debug] StopArrivalsViewModel.deinit called for stopID: \(stopID)")
        refreshTask?.cancel()
    }
    
    @Published var isOfflineMode = false

    private func cacheKey(for id: OBAStopID) -> String {
        "cache.arrivals.\(id)"
    }

    private func saveToCache(_ result: OBAArrivalsResult) {
        if let data = try? JSONEncoder().encode(result) {
            UserDefaults.standard.set(data, forKey: cacheKey(for: stopID))
        }
    }

    private func loadFromCache() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: cacheKey(for: stopID)),
              let result = try? JSONDecoder().decode(OBAArrivalsResult.self, from: data) else {
            return false
        }
        arrivals = result.arrivals
        if !result.routes.isEmpty { routes = result.routes }
        if let name = result.stopName { stopName = name }
        isOfflineMode = true
        errorMessage = nil
        return true
    }
    
    func loadArrivals() async {
        guard !isLoading else { return }
        
        let apiClient = apiClientProvider()
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        
        do {
            let result = try await apiClient.fetchArrivals(for: stopID)
            arrivals = result.arrivals
            isOfflineMode = false
            saveToCache(result)
            
            // Update routes if we got them from the arrivals response
            if !result.routes.isEmpty {
                routes = result.routes
            }
            
            // Update stop name if we got it
            if let fetchedName = result.stopName {
                stopName = fetchedName

                // Save to recent stops using real coordinates if the server returned them.
                saveToRecentStops(
                    name: fetchedName,
                    code: result.stopCode,
                    direction: result.stopDirection,
                    latitude: result.stopLatitude,
                    longitude: result.stopLongitude
                )
            }
            
            lastUpdated = Date()
        } catch {
            if !loadFromCache() {
                errorMessage = error.watchOSUserFacingMessage
            }
        }
    }

    private func saveToRecentStops(
        name: String,
        code: String? = nil,
        direction: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        let routeNames = routes.compactMap { $0.shortName }.joined(separator: ", ")

        // Use real server coordinates when available; fall back to 0,0 only as a
        // last resort. Views that show distance should check for the zero sentinel
        // and suppress the distance label in that case.
        let lat = latitude ?? 0.0
        let lon = longitude ?? 0.0
        if lat == 0.0 && lon == 0.0 {
            Logger.warn("saveToRecentStops: No coordinates available for stop \(stopID) — distance display will be suppressed in views.")
        }

        let stop = OBAStop(
            id: stopID,
            name: name,
            latitude: lat,
            longitude: lon,
            code: code,
            direction: direction,
            routeNames: routeNames.isEmpty ? nil : routeNames
        )

        RecentStopsViewModel.shared.addRecentStop(stop)

        // Notify other views
        NotificationCenter.default.post(name: .RecentStopsUpdated, object: nil)
    }

    func loadRoutes() async {
        let apiClient = apiClientProvider()
        do {
            let fetched = try await apiClient.fetchRoutesForStop(stopID: stopID)
            routes = fetched
        } catch is CancellationError {
            return
        } catch let apiError as OBAAPIError {
            Logger.error("loadRoutes failed: \(apiError)")
        } catch {
            Logger.error("loadRoutes failed with unknown error: \(error)")
            // We don't want to show an error message here, as it might
            // overwrite a more important error from `loadArrivals`.
        }
    }
    
    var upcomingArrivals: [OBAArrival] {
        arrivals.filter { $0.minutesFromNow >= 0 }
    }
}
