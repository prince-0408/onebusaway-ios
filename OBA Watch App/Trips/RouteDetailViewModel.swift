import Foundation
import Combine
import CoreLocation
import OBAKitCore

@MainActor
final class RouteDetailViewModel: ObservableObject {
    @Published var directions: [OBARouteDirection] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var shapeCoordinates: [CLLocationCoordinate2D] = []
    @Published var vehicleCoordinates: [CLLocationCoordinate2D] = []
    @Published var serviceAlerts: [WatchServiceAlert] = []

    private let apiClient: OBAAPIClient
    private let routeID: OBARouteID

    init(apiClient: OBAAPIClient, routeID: OBARouteID) {
        self.apiClient = apiClient
        self.routeID = routeID
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            // 1. Fetch stops for route
            let result = try await apiClient.fetchStopsForRoute(routeID: routeID)
            directions = result

            // 2. Fetch shape ID and path (optional, don't fail if this fails)
            do {
                if let shapeID = try await apiClient.fetchShapeIDForRoute(routeID: routeID) {
                    let encoded = try await apiClient.fetchShape(shapeID: shapeID)
                    shapeCoordinates = PolylineDecoder.decode(encodedPolyline: encoded)
                }
            } catch {
                Logger.error("Failed to fetch shape for route \(routeID): \(error)")
            }

            // 3. Fetch real-time vehicle coordinates for route
            do {
                let trips = try await apiClient.fetchTripsForRoute(routeID: routeID)
                self.vehicleCoordinates = trips.compactMap { trip -> CLLocationCoordinate2D? in
                    guard let lat = trip.latitude, let lon = trip.longitude, lat != 0.0, lon != 0.0 else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            } catch {
                Logger.error("Failed to fetch vehicles for route \(routeID): \(error)")
            }

            // 4. Fetch service alerts for route (optional)
            do {
                let alerts = try await apiClient.fetchServiceAlerts(agencyID: nil)
                let cleanRouteID = routeID.components(separatedBy: "_").last ?? routeID
                self.serviceAlerts = alerts.filter { alert in
                    alert.title.localizedCaseInsensitiveContains(cleanRouteID) ||
                    (alert.body?.localizedCaseInsensitiveContains(cleanRouteID) ?? false)
                }
            } catch {
                Logger.info("No service alerts for route \(routeID)")
            }
        } catch let apiError as OBAAPIError {
            errorMessage = apiError.errorDescription ?? OBALoc("common.api_error", value: "API Error", comment: "API error")
        } catch {
            errorMessage = error.watchOSUserFacingMessage
        }

        isLoading = false
    }
}
