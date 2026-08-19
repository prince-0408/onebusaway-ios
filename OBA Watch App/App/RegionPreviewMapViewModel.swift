//
//  RegionPreviewMapViewModel.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 19/08/26.
//

import Foundation
import CoreLocation
import OBAKitCore

@MainActor
final class RegionPreviewMapViewModel: ObservableObject {
    @Published var stops: [OBAStop] = []

    func loadStops(around coordinate: CLLocationCoordinate2D, apiClient: OBAAPIClient) async {
        do {
            let fetched = try await apiClient.fetchNearbyStops(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: 1500.0
            )
            stops = fetched.stops
        } catch {
            Logger.error("Failed to load stops for preview map: \(error)")
            // For the preview map, we silently ignore errors and leave the base map.
        }
    }
}
