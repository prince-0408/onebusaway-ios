import Foundation
import CoreLocation
import Combine
import OBAKitCore
import MapKit


@MainActor
final class RouteSearchViewModel: ObservableObject {
    @Published var query: String
    @Published var routes: [OBARoute] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let apiClient: OBAAPIClient
    private let locationProvider: () -> CLLocation?
    private var searchTask: Task<Void, Never>?
    private let geocoder = CLGeocoder()

    init(initialQuery: String, apiClient: OBAAPIClient, locationProvider: @escaping () -> CLLocation?) {
        self.query = initialQuery
        self.apiClient = apiClient
        self.locationProvider = locationProvider
    }

    func performSearch() {
        searchTask?.cancel()
        searchTask = Task {
            await self._performSearch()
        }
    }

    private func _performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isLoading = true
        errorMessage = nil
        routes = []

        var searchLocation: CLLocation?
        var searchRegion: MKMapRect?

        do {
            do {
                // Pass query: nil so route names like "10" or "C Line" are not incorrectly geocoded as street addresses
                let resolved = try await LocationResolver.resolve(
                    query: nil,
                    geocoder: geocoder,
                    apiClient: apiClient,
                    locationProvider: locationProvider
                )
                searchLocation = resolved.0
                searchRegion = resolved.1
            } catch {
                self.errorMessage = error.watchOSUserFacingMessage
                isLoading = false
                return
            }

            if let searchLoc = searchLocation {
                await self.executeSearch(trimmed: trimmed, location: searchLoc, searchRegion: searchRegion)
            } else if let fallbackLoc = locationProvider() {
                await self.executeSearch(trimmed: trimmed, location: fallbackLoc, searchRegion: nil)
            } else {
                self.errorMessage = OBALoc("search.error.location_required", value: "Location required for route search", comment: "Location required error message")
            }
        } catch {
            self.errorMessage = error.watchOSUserFacingMessage
        }
        
        self.isLoading = false
    }

    private func executeSearch(trimmed: String, location: CLLocation, searchRegion: MKMapRect?) async {
        do {
            let fetched = try await apiClient.searchRoutes(
                query: trimmed,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 25000.0
            )
            
            if !fetched.isEmpty {
                self.routes = fetched
                return
            }
            
            // Fallback 1: Fetch all routes in regional area and filter client-side.
            let allLocalRoutes = try await apiClient.searchRoutes(
                query: "",
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 25000.0
            )
            
            let queryLower = trimmed.lowercased()
            var filtered = allLocalRoutes.filter { route in
                if let short = route.shortName?.lowercased(), short.contains(queryLower) { return true }
                if let long = route.longName?.lowercased(), long.contains(queryLower) { return true }
                if route.id.lowercased().contains(queryLower) { return true }
                return false
            }
            
            if !filtered.isEmpty {
                self.routes = filtered
                return
            }

            // Fallback 2: Search stops matching query (e.g. location/landmark name like "Malta" or "Pike")
            // and gather the routes serving those matching stops.
            let stopResults = try await apiClient.searchStops(
                query: trimmed,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 25000.0
            )
            
            var discoveredRoutes: [OBARoute] = []
            var seenRouteIDs = Set<String>()
            
            for stop in stopResults.stops.prefix(5) {
                if let routesForStop = try? await apiClient.fetchRoutesForStop(stopID: stop.id) {
                    for r in routesForStop {
                        if !seenRouteIDs.contains(r.id) {
                            seenRouteIDs.insert(r.id)
                            discoveredRoutes.append(r)
                        }
                    }
                }
            }
            
            self.routes = discoveredRoutes
        } catch {
            self.errorMessage = error.watchOSUserFacingMessage
        }
    }
}
