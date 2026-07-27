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
    @Published var stopLatitude: Double?
    @Published var stopLongitude: Double?
    @Published var selectedRouteFilter: String? = nil
    @Published var transferContext: TransferContext? = nil

    var filteredArrivals: [OBAArrival] {
        let prefs = StopPreferencesStore.shared.preferences(for: stopID)
        let unhidden = arrivals.filter { arrival in
            let routeID = arrival.routeID ?? arrival.routeShortName ?? ""
            return !prefs.isRouteIDHidden(routeID)
        }
        guard let filter = selectedRouteFilter, !filter.isEmpty else {
            return unhidden
        }
        return unhidden.filter { arrival in
            arrival.routeID == filter || arrival.routeShortName == filter
        }
    }

    var upcomingFilteredArrivals: [OBAArrival] {
        filteredArrivals.filter { $0.minutesFromNow >= -2 }
    }

    var availableRouteFilters: [String] {
        let routeNames = arrivals.compactMap { $0.routeShortName ?? $0.routeID }
        return Array(Set(routeNames)).sorted()
    }

    /// Calculates relative departure info relative to a transfer arrival time.
    func relativeTransferInfo(for arrival: OBAArrival) -> (text: String, isMissed: Bool)? {
        guard let context = transferContext else { return nil }
        let departureDate = arrival.arrivalTime ?? Date()
        let minutes = context.minutesUntilDeparture(from: departureDate)
        if minutes < 0 {
            return ("Missed (\(abs(minutes))m ago)", true)
        } else if minutes == 0 {
            return ("Departs at arrival", false)
        } else {
            return ("+\(minutes)m post-transfer", false)
        }
    }
    
    private let apiClientProvider: () -> OBAAPIClient
    private let stopID: OBAStopID
    /// Single task that handles both the initial load and the periodic refresh loop.
    /// Cancelling this task stops any in-flight network call immediately.
    private var refreshTask: Task<Void, Never>?
    
    init(apiClientProvider: @escaping () -> OBAAPIClient, stopID: OBAStopID, transferContext: TransferContext? = nil) {
        self.apiClientProvider = apiClientProvider
        self.stopID = stopID
        self.transferContext = transferContext
        startRefreshLoop()
    }

    /// Starts (or restarts) the initial-load + 30-second refresh loop.
    func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Initial load
            await self.loadArrivals()
            await self.loadRoutes()
            // Periodic refresh
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                } catch {
                    // CancellationError — stop the loop cleanly
                    break
                }
                guard !Task.isCancelled else { break }
                await self.loadArrivals()
            }
        }
    }

    /// Call this as soon as the view begins to disappear so the back-button
    /// animation is never blocked by an in-flight network request.
    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
        // Reset loading flag so the view doesn't stay in a spinner state
        // if it somehow becomes visible again (e.g. swipe-back cancelled).
        isLoading = false
    }

    deinit {
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
        guard !Task.isCancelled else { return }
        
        let apiClient = apiClientProvider()
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await apiClient.fetchArrivals(for: stopID)
            guard !Task.isCancelled else {
                isLoading = false
                return
            }
            arrivals = result.arrivals
            isOfflineMode = false
            isLoading = false
            saveToCache(result)
            
            if !result.routes.isEmpty {
                routes = result.routes
            }
            
            stopLatitude = result.stopLatitude
            stopLongitude = result.stopLongitude
            
            if let fetchedName = result.stopName {
                stopName = fetchedName
                saveToRecentStops(
                    name: fetchedName,
                    code: result.stopCode,
                    direction: result.stopDirection,
                    latitude: result.stopLatitude,
                    longitude: result.stopLongitude
                )
            }
            
            lastUpdated = Date()
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            isLoading = false
            guard !Task.isCancelled else { return }
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
        guard !Task.isCancelled else { return }
        let apiClient = apiClientProvider()
        do {
            let fetched = try await apiClient.fetchRoutesForStop(stopID: stopID)
            guard !Task.isCancelled else { return }
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
