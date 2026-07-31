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
    @State private var routePolyline: [CLLocationCoordinate2D] = []
    @State private var polylineRouteID: String? = nil
    @StateObject private var glider = VehiclePolylineGlider()
    
    @AppStorage("watch_map_style_raw", store: WatchAppState.userDefaults) private var mapStyleRaw: String = "standard"

    private var activeMapStyle: MapStyle {
        if mapStyleRaw == "transit" {
            return .standard(pointsOfInterest: .excludingAll)
        } else {
            return .standard(pointsOfInterest: .all)
        }
    }

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
                
                // Draw route line - Passed (Muted Slate Gray) & Upcoming (Vibrant Mint Green)
                if !routePolyline.isEmpty {
                    MapPolyline(coordinates: routePolyline)
                        .stroke(Color.black.opacity(0.85), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

                    if !passedRoutePolyline.isEmpty {
                        MapPolyline(coordinates: passedRoutePolyline)
                            .stroke(
                                Color(red: 0.35, green: 0.45, blue: 0.58).opacity(0.75),
                                style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                            )
                    }

                    if !upcomingRoutePolyline.isEmpty {
                        MapPolyline(coordinates: upcomingRoutePolyline)
                            .stroke(
                                Color.brand.gradient,
                                style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
                
                // Stops: Markers with train or bus symbol based on transit mode
                ForEach(displayedStops) { stop in
                    if stop.latitude != 0.0 || stop.longitude != 0.0 {
                        let coord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                        Marker(
                            stop.name,
                            systemImage: stop.iconName,
                            coordinate: coord
                        )
                        .tint(stop.isTrain ? .indigo : .brand)
                        .tag(stop.id)
                    }
                }
                
                // Vehicles: Animated Blinking & Pulsing Vehicle Markers
                ForEach(displayedVehicles) { vehicle in
                    if let lat = vehicle.latitude, let lon = vehicle.longitude {
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Annotation(
                            vehicle.routeShortName ?? "Bus",
                            coordinate: coord
                        ) {
                            PulsingVehicleMarker(
                                title: vehicle.routeShortName ?? "Bus",
                                heading: vehicle.orientation ?? (glider.currentHeading != 0 ? glider.currentHeading : 0),
                                isTracked: trackedVehicle?.id == vehicle.id || trackedVehicle?.vehicleID == vehicle.vehicleID
                            )
                        }
                        .tag(vehicle.id)
                    }
                }
            }
            .mapStyle(activeMapStyle)
            .id(mapStyleRaw)
            .mapControlVisibility(.hidden)
            
            // Tracked Vehicle Floating Banner
            if let vehicle = trackedVehicle {
                HStack(spacing: 8) {
                    // Left circle badge
                    ZStack {
                        Circle()
                            .fill(Color.brand.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "bus.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.brand)
                    }
                    
                    // Middle text info
                    VStack(alignment: .leading, spacing: 0) {
                        if let lat = vehicle.latitude, let lon = vehicle.longitude {
                            Text(formattedDistance(latitude: lat, longitude: lon))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                        } else {
                            Text("Tracking")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Text(vehicle.tripHeadsign ?? vehicle.routeShortName ?? "Vehicle")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Direction Arrow (Live)
                    if let lat = vehicle.latitude, let lon = vehicle.longitude {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.brand)
                            .rotationEffect(Angle(degrees: relativeBearing(lat: lat, lon: lon) - 45))
                            .padding(.trailing, 2)
                    }
                    
                    // Close button
                    Button {
                        withAnimation {
                            trackedVehicle = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(5)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 6)
                .padding(.top, 4)
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
            
            // Map Overlay Controls (Grouped Bottom-Right Stack)
            VStack(spacing: 8) {
                // Transit Map Filter Toggle Button
                Button {
                    withAnimation {
                        mapStyleRaw = (mapStyleRaw == "transit") ? "standard" : "transit"
                    }
                } label: {
                    Image(systemName: mapStyleRaw == "transit" ? "bus.fill" : "map")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(mapStyleRaw == "transit" ? .brand : .primary)
                        .padding(8)
                        .background(Circle().fill(.ultraThinMaterial))
                        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)

                // Location Recenter Button
                Button {
                    let loc = appState.effectiveLocation
                    withAnimation {
                        trackedVehicle = nil
                        mapPosition = .region(MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 800, longitudinalMeters: 800))
                    }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.brand)
                        .padding(8)
                        .background(Circle().fill(.ultraThinMaterial))
                        .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
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
        .onChange(of: trackedVehicle) { _, newVehicle in
            if let newVehicle = newVehicle, let routeID = newVehicle.routeID {
                Task {
                    await loadRoutePolyline(routeID: routeID)
                }
            } else {
                withAnimation {
                    routePolyline = []
                    polylineRouteID = nil
                }
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
                if let lat = updated.latitude, let lon = updated.longitude {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    glider.setTargetLocation(coord)
                    withAnimation(.easeInOut(duration: 2.5)) {
                        self.trackedVehicle = updated
                        self.mapPosition = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 500, longitudinalMeters: 500))
                    }
                } else {
                    withAnimation(.easeInOut(duration: 2.5)) {
                        self.trackedVehicle = updated
                    }
                }
            }
        } catch {
            Logger.error("Failed to fetch live vehicles for map: \(error)")
        }
    }
    
    private func loadRoutePolyline(routeID: String) async {
        guard polylineRouteID != routeID else { return }
        polylineRouteID = routeID
        do {
            if let shapeID = try await appState.apiClient.fetchShapeIDForRoute(routeID: routeID) {
                let encodedPoints = try await appState.apiClient.fetchShape(shapeID: shapeID)
                let decoded = PolylineDecoder.decode(encodedPolyline: encodedPoints)
                withAnimation {
                    self.routePolyline = decoded
                }
                glider.updatePolyline(decoded)
            } else {
                withAnimation {
                    self.routePolyline = []
                }
            }
        } catch {
            Logger.error("Failed to fetch shape for route \(routeID): \(error)")
            withAnimation {
                self.routePolyline = []
            }
        }
    }

    private func formattedDistance(latitude: Double, longitude: Double) -> String {
        let userLoc = appState.currentLocation ?? appState.effectiveLocation
        let vehicleLoc = CLLocation(latitude: latitude, longitude: longitude)
        let distance = userLoc.distance(from: vehicleLoc)
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000.0)
        }
    }
    
    private func relativeBearing(lat: Double, lon: Double) -> Double {
        let userLoc = appState.currentLocation ?? appState.effectiveLocation
        let from = userLoc.coordinate
        let to = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        return bearing(from: from, to: to)
    }
    
    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        return radians * 180 / .pi
    }
    
    private var polylineSplitIndex: Int? {
        guard let vehicle = trackedVehicle,
              let lat = vehicle.latitude, let lon = vehicle.longitude,
              !routePolyline.isEmpty else { return nil }
        let vCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        var minDistance: Double = .greatestFiniteMagnitude
        var closestIndex = 0
        for (idx, coord) in routePolyline.enumerated() {
            let dist = haversine(vCoord, coord)
            if dist < minDistance {
                minDistance = dist
                closestIndex = idx
            }
        }
        return closestIndex
    }

    private var passedRoutePolyline: [CLLocationCoordinate2D] {
        let gPassed = glider.passedPolyline
        if !gPassed.isEmpty { return gPassed }
        guard let idx = polylineSplitIndex, idx > 0 else { return [] }
        return Array(routePolyline[0...idx])
    }

    private var upcomingRoutePolyline: [CLLocationCoordinate2D] {
        let gUpcoming = glider.upcomingPolyline
        if !gUpcoming.isEmpty { return gUpcoming }
        guard let idx = polylineSplitIndex else { return routePolyline }
        return Array(routePolyline[idx..<routePolyline.count])
    }

    private func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let phi1 = a.latitude * .pi / 180
        let phi2 = b.latitude * .pi / 180
        let dphi = (b.latitude - a.latitude) * .pi / 180
        let dl = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dphi/2)*sin(dphi/2) + cos(phi1)*cos(phi2)*sin(dl/2)*sin(dl/2)
        return 2 * R * asin(sqrt(h))
    }
}
