//
//  WatchInteractiveMapView.swift
//  OBA Watch App
//

import SwiftUI
import MapKit
import CoreLocation
import OBAKitCore

struct WatchInteractiveMapView: View {
    @EnvironmentObject var appState: WatchAppState
    
    let initialRegion: MKCoordinateRegion?
    let stops: [OBAStop]
    let vehicles: [OBAVehicle]
    
    @State private var mapPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedStop: OBAStop?
    @State private var showStopArrivals: Bool = false
    @State private var selectedMarkerID: String?
    @State private var trackedVehicle: OBATripForLocation?
    
    @State private var liveVehicles: [OBATripForLocation] = []
    @State private var isLoading = false
    @State private var timer: Timer?
    
    init(initialRegion: MKCoordinateRegion? = nil, stops: [OBAStop] = [], vehicles: [OBAVehicle] = []) {
        self.initialRegion = initialRegion
        self.stops = stops
        self.vehicles = vehicles
    }
    
    private var displayedStops: [OBAStop] {
        Array(stops.prefix(20))
    }
    
    private var displayedVehicles: [OBATripForLocation] {
        if !liveVehicles.isEmpty {
            return liveVehicles
        } else {
            return vehicles.compactMap { $0.toTripForLocation() }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $mapPosition, selection: $selectedMarkerID) {
                UserAnnotation()
                
                // Stops: Blue Markers with a distinct signpost/train symbol (not a bus)
                ForEach(displayedStops) { stop in
                    if stop.latitude != 0.0 || stop.longitude != 0.0 {
                        let coord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                        Marker(
                            stop.name,
                            systemImage: stop.locationType == 1 ? "train" : "signpost.right.and.left.fill",
                            coordinate: coord
                        )
                        .tint(.blue)
                        .tag(stop.id)
                    }
                }
                
                // Vehicles: Green Markers with a bus symbol
                ForEach(displayedVehicles) { vehicle in
                    if let lat = vehicle.latitude, let lon = vehicle.longitude {
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Marker(
                            vehicle.routeShortName ?? "Bus",
                            systemImage: "bus.fill",
                            coordinate: coord
                        )
                        .tint(.green)
                        .tag(vehicle.id)
                    }
                }
            }
            .mapStyle(appState.mapStyle)
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            
            // Tracked Vehicle Floating Banner
            if let vehicle = trackedVehicle {
                HStack(spacing: 6) {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Tracking \(vehicle.routeShortName ?? "Bus")")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Button {
                        withAnimation {
                            trackedVehicle = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.8)))
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            
            // Loading Indicator Overlay
            if isLoading {
                ProgressView()
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.6)))
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            
            // Floating Recenter Button
            Button {
                let loc = appState.effectiveLocation
                withAnimation {
                    trackedVehicle = nil
                    mapPosition = .region(MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
                }
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Circle().fill(Color.blue.gradient))
                    .shadow(radius: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
        }
        .navigationTitle(OBALoc("map.interactive_title", value: "Map", comment: "Interactive map screen title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStopArrivals) {
            if let stop = selectedStop {
                NavigationStack {
                    StopArrivalsView(stopID: stop.id, stopName: stop.name)
                }
            }
        }
        .onAppear {
            // Set initial position once on mount
            if let reg = initialRegion {
                mapPosition = .region(reg)
            } else if let firstStop = stops.first, firstStop.latitude != 0.0, firstStop.longitude != 0.0 {
                let coord = CLLocationCoordinate2D(latitude: firstStop.latitude, longitude: firstStop.longitude)
                let reg = MKCoordinateRegion(center: coord, latitudinalMeters: 800, longitudinalMeters: 800)
                mapPosition = .region(reg)
            } else {
                let loc = appState.effectiveLocation
                let reg = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
                mapPosition = .region(reg)
            }

            Task {
                await loadOverlays()
            }
            timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
                Task {
                    await fetchLiveVehicles()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .onChange(of: selectedMarkerID) { _, newID in
            guard let newID = newID else { return }
            if let stop = stops.first(where: { $0.id == newID }) {
                selectedStop = stop
                showStopArrivals = true
                selectedMarkerID = nil // Reset selection
            } else if let vehicle = displayedVehicles.first(where: { $0.id == newID || $0.vehicleID == newID }) {
                withAnimation {
                    trackedVehicle = vehicle
                    if let lat = vehicle.latitude, let lon = vehicle.longitude {
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        mapPosition = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500))
                    }
                }
                selectedMarkerID = nil
            }
        }
    }
    
    private func loadOverlays() async {
        isLoading = true
        await fetchLiveVehicles()
        isLoading = false
    }
    
    private func fetchLiveVehicles() async {
        let center: CLLocationCoordinate2D
        if let reg = initialRegion {
            center = reg.center
        } else if let firstStop = stops.first {
            center = CLLocationCoordinate2D(latitude: firstStop.latitude, longitude: firstStop.longitude)
        } else {
            center = appState.effectiveLocation.coordinate
        }
        
        do {
            let trips = try await appState.apiClient.fetchVehiclesReliably(
                latitude: center.latitude,
                longitude: center.longitude,
                latSpan: 0.015,
                lonSpan: 0.015
            )
            self.liveVehicles = trips
            
            // Auto-center camera if tracking a vehicle
            if let tracked = trackedVehicle, let updated = trips.first(where: { $0.id == tracked.id || $0.vehicleID == tracked.vehicleID }) {
                self.trackedVehicle = updated
                if let lat = updated.latitude, let lon = updated.longitude {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    withAnimation {
                        mapPosition = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500))
                    }
                }
            }
        } catch {
            Logger.error("Failed to fetch live vehicles for map: \(error)")
        }
    }
}
