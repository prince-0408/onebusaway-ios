//
//  RegionPreviewMapView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import MapKit
import OBAKitCore

/// Simple map showing the selected region from onboarding, with nearby stops.
struct RegionPreviewMapView: View {
    @EnvironmentObject var appState: WatchAppState
    @AppStorage("watch_selected_region_id", store: WatchAppState.userDefaults) private var selectedRegionID: String = "mta-new-york"
    @StateObject private var viewModel = RegionPreviewMapViewModel()

    private var centerCoordinate: CLLocationCoordinate2D {
        if let region = appState.regions.first(where: { $0.id == selectedRegionID }) {
            return region.coordinate
        }
        return .init(latitude: 40.7128, longitude: -74.0060)
    }

    var body: some View {
        let region = MKCoordinateRegion(
            center: centerCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.25, longitudeDelta: 0.25)
        )

        ZStack(alignment: .topTrailing) {
            if !viewModel.stops.isEmpty {
                let previewLocation = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
                NearbyMapView(
                    stops: Array(viewModel.stops.prefix(60)),
                    currentLocation: previewLocation,
                    mapStyle: appState.mapStyle
                )
                .id("standard")
            } else {
                Map(coordinateRegion: .constant(region))
                    .mapStyle(appState.mapStyle)
                    .id("standard")
            }
        }
        .onAppear {
            Task {
                await viewModel.loadStops(around: centerCoordinate, apiClient: WatchAppState.shared.apiClient)
            }
        }
    }
}

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
