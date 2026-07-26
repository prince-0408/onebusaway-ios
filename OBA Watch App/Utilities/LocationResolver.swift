import Foundation
import CoreLocation
import MapKit
import OBAKitCore

struct LocationResolver {
    static func resolve(
        query: String?,
        geocoder: CLGeocoder,
        apiClient: OBAAPIClient,
        locationProvider: () -> CLLocation?
    ) async throws -> (CLLocation, MKMapRect?) {
        var searchLocation = locationProvider()
        var searchRegion: MKMapRect?
        var agencies: [OBAAgencyCoverage]?

        let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            do {
                let placemarks = try await geocoder.geocodeAddressString(trimmed)
                if let loc = placemarks.first?.location {
                    searchLocation = loc
                } else {
                    agencies = try await apiClient.fetchAgenciesWithCoverage()
                    if let bound = agencies?.first?.agencyRegionBound {
                        searchRegion = bound.serviceRect
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                agencies = try await apiClient.fetchAgenciesWithCoverage()
                if let bound = agencies?.first?.agencyRegionBound {
                    searchRegion = bound.serviceRect
                }
            }
        }

        // Verify location proximity to the active region coverage center.
        do {
            if agencies == nil {
                agencies = try await apiClient.fetchAgenciesWithCoverage()
            }
            if let first = agencies?.first {
                let regionCenter = CLLocation(latitude: first.centerLatitude, longitude: first.centerLongitude)
                if let deviceLoc = searchLocation {
                    let distance = deviceLoc.distance(from: regionCenter)
                    if distance > 150_000 {
                        searchLocation = regionCenter
                        searchRegion = first.agencyRegionBound.serviceRect
                    }
                } else {
                    searchLocation = regionCenter
                    searchRegion = first.agencyRegionBound.serviceRect
                }
            }
        } catch {
            Logger.error("LocationResolver failed to verify agency coverage proximity: \(error)")
        }

        guard let finalLocation = searchLocation else {
            throw NSError(domain: "LocationResolver", code: 1, userInfo: [NSLocalizedDescriptionKey: OBALoc("search.error.location_required", value: "Location required for search", comment: "Location required")])
        }
        return (finalLocation, searchRegion)
    }

    /// Evaluates proximity from `location` to available regions and returns the nearest region if within range.
    static func bestMatchingRegion(
        for location: CLLocation,
        regions: [WatchAppState.RegionOption],
        maxDistanceMeters: CLLocationDistance = 80_000
    ) -> WatchAppState.RegionOption? {
        var closestRegion: WatchAppState.RegionOption?
        var minDistance: CLLocationDistance = .infinity

        for region in regions {
            let regionLoc = CLLocation(latitude: region.coordinate.latitude, longitude: region.coordinate.longitude)
            let distance = location.distance(from: regionLoc)
            if distance < minDistance {
                minDistance = distance
                closestRegion = region
            }
        }

        if minDistance <= maxDistanceMeters {
            return closestRegion
        }
        return nil
    }
}
