//
//  SearchViewModel.swift
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
class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [OBAStop] = []
    @Published var routeResults: [OBARoute] = []
    @Published var vehicleResults: [OBAVehicle] = []
    @Published var bookmarkResults: [WatchBookmark] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var recentStops: [OBAStop] = []
    @Published var recentSearchTerms: [String] = []
    
    private let apiClientProvider: () -> OBAAPIClient
    private let locationProvider: () -> CLLocation?
    private var searchTask: Task<Void, Never>?
    private let recentStopsKey = "OBASharedRecentStops"
    private let recentSearchTermsKey = "watch_recent_search_terms"
    private let bookmarksKey = "watch.bookmarks"

    init(apiClientProvider: @escaping () -> OBAAPIClient, locationProvider: @escaping () -> CLLocation?) {
        self.apiClientProvider = apiClientProvider
        self.locationProvider = locationProvider
        self.recentStops = RecentStopsViewModel.shared.recentStops
        self.recentSearchTerms = WatchAppState.userDefaults.stringArray(forKey: recentSearchTermsKey) ?? []
        self.bookmarkResults = Self.loadBookmarks(from: bookmarksKey)
    }
    
    func performSearch() {
        searchTask?.cancel()
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            routeResults = []
            vehicleResults = []
            bookmarkResults = []
            return
        }
        
        // Save to recent search terms if not already there or move to top
        updateRecentSearchTerms(term: trimmed)
        
        searchTask = Task {
            async let stopsTask: () = searchStops(query: trimmed)
            async let routesTask: () = searchRoutes(query: trimmed)
            async let vehicleTask: () = searchVehicle(query: trimmed)
            filterBookmarks(matching: trimmed)
            _ = await (stopsTask, routesTask, vehicleTask)
        }
    }

    private func updateRecentSearchTerms(term: String) {
        var terms = recentSearchTerms
        terms.removeAll { $0.lowercased() == term.lowercased() }
        terms.insert(term, at: 0)
        if terms.count > 5 {
            terms = Array(terms.prefix(5))
        }
        recentSearchTerms = terms
        WatchAppState.userDefaults.set(terms, forKey: recentSearchTermsKey)
    }

    func selectRecentSearchTerm(_ term: String) {
        searchText = term
        performSearch()
    }

    func clearRecentSearchTerms() {
        recentSearchTerms = []
        WatchAppState.userDefaults.removeObject(forKey: recentSearchTermsKey)
    }

    func recordRecent(stop: OBAStop) {
        RecentStopsViewModel.shared.addRecentStop(stop)
        recentStops = RecentStopsViewModel.shared.recentStops
    }
    
    private func searchStops(query: String) async {
        let apiClient = apiClientProvider()
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }

        var location: CLLocation
        do {
            let resolved = try await LocationResolver.resolve(
                query: query,
                geocoder: CLGeocoder(),
                apiClient: apiClient,
                locationProvider: locationProvider
            )
            location = resolved.0
        } catch {
            errorMessage = error.watchOSUserFacingMessage
            return
        }
        
        do {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let fetched = try await apiClient.searchStops(
                query: trimmed,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 5000.0
            )

            searchResults = fetched.stops.sorted { (s1: OBAStop, s2: OBAStop) in
                let loc1 = CLLocation(latitude: s1.latitude, longitude: s1.longitude)
                let loc2 = CLLocation(latitude: s2.latitude, longitude: s2.longitude)
                let d1 = loc1.distance(from: location)
                let d2 = loc2.distance(from: location)
                return d1 < d2
            }
        } catch {
            errorMessage = error.watchOSUserFacingMessage
        }
    }

    private func searchRoutes(query: String) async {
        let apiClient = apiClientProvider()
        let location = locationProvider() ?? CLLocation(latitude: 47.6062, longitude: -122.3321)
        do {
            let fetched = try await apiClient.searchRoutes(
                query: query,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 25000.0
            )
            if !fetched.isEmpty {
                self.routeResults = Array(fetched.prefix(5))
                return
            }
            
            // Fallback 1: fetch all local routes and filter client side
            let allLocal = try await apiClient.searchRoutes(
                query: "",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 25000.0
            )
            let q = query.lowercased()
            let filtered = allLocal.filter { r in
                if let short = r.shortName?.lowercased(), short.contains(q) { return true }
                if let long = r.longName?.lowercased(), long.contains(q) { return true }
                return r.id.lowercased().contains(q)
            }
            
            if !filtered.isEmpty {
                self.routeResults = Array(filtered.prefix(5))
                return
            }

            // Fallback 2: Search stops matching query (e.g. location/landmark name) and discover routes
            let stopResults = try await apiClient.searchStops(
                query: query,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 25000.0
            )
            var discovered: [OBARoute] = []
            var seenIDs = Set<String>()
            for stop in stopResults.stops.prefix(5) {
                if let routesForStop = try? await apiClient.fetchRoutesForStop(stopID: stop.id) {
                    for r in routesForStop {
                        if !seenIDs.contains(r.id) {
                            seenIDs.insert(r.id)
                            discovered.append(r)
                        }
                    }
                }
            }
            self.routeResults = Array(discovered.prefix(5))
        } catch {
            // Silently fail route search if not matching
            self.routeResults = []
        }
    }

    private func searchVehicle(query: String) async {
        guard query.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil else {
            self.vehicleResults = []
            return
        }
        let apiClient = apiClientProvider()
        do {
            let vehicle = try await apiClient.fetchVehicle(vehicleID: query)
            self.vehicleResults = [vehicle]
        } catch {
            self.vehicleResults = []
        }
    }

    private func filterBookmarks(matching query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let all = Self.loadBookmarks(from: bookmarksKey)
        guard !trimmed.isEmpty else {
            bookmarkResults = []
            return
        }
        bookmarkResults = all.filter { bm in
            if bm.name.localizedCaseInsensitiveContains(trimmed) { return true }
            if let route = bm.routeShortName, route.localizedCaseInsensitiveContains(trimmed) { return true }
            if let headsign = bm.tripHeadsign, headsign.localizedCaseInsensitiveContains(trimmed) { return true }
            if let stop = bm.stop {
                if stop.name.localizedCaseInsensitiveContains(trimmed) { return true }
                if let code = stop.code, code.localizedCaseInsensitiveContains(trimmed) { return true }
            }
            return false
        }
    }

    private static func loadRecentStops(from key: String) -> [OBAStop] { RecentStopsViewModel.shared.recentStops }

    private static func loadBookmarks(from key: String) -> [WatchBookmark] {
        guard let data = WatchAppState.userDefaults.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode([WatchBookmark].self, from: data)
        } catch {
            Logger.error("Failed to decode bookmarks: \(error)")
            return []
        }
    }
}
