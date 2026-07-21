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
        print("[WatchOS Debug] _performSearch start. query = '\(trimmed)'")
        
        isLoading = true
        errorMessage = nil
        routes = []

        var searchLocation: CLLocation?
        var searchRegion: MKMapRect?

        do {
            do {
                let resolved = try await LocationResolver.resolve(query: trimmed.isEmpty ? nil : trimmed, geocoder: geocoder, apiClient: apiClient, locationProvider: locationProvider)
                searchLocation = resolved.0
                searchRegion = resolved.1
                print("[WatchOS Debug] resolved searchLocation = \(String(describing: searchLocation?.coordinate)), searchRegion = \(String(describing: searchRegion))")
            } catch {
                print("[WatchOS Debug] LocationResolver failed with error: \(error)")
                self.errorMessage = error.watchOSUserFacingMessage
                isLoading = false
                return
            }

            if searchLocation == nil {
                self.errorMessage = OBALoc("search.error.location_required", value: "Location required for route search", comment: "Location required error message")
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
        let queryForAPI: String = trimmed.contains(" ") ? "" : trimmed
        print("[WatchOS Debug] executeSearch start. queryForAPI = '\(queryForAPI)', lat = \(location.coordinate.latitude), lon = \(location.coordinate.longitude)")
        do {
            let fetched = try await apiClient.searchRoutes(
                query: queryForAPI,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radius: 150000.0
            )
            print("[WatchOS Debug] searchRoutes returned \(fetched.count) routes: \(fetched.map { $0.shortName ?? "?" })")
            self.routes = fetched
        } catch {
            print("[WatchOS Debug] searchRoutes failed with error: \(error)")
            self.errorMessage = error.watchOSUserFacingMessage
        }
    }
}
