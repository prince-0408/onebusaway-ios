//
//  TripDetailsView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore
import MapKit

struct TripDetailsView: View {
    @StateObject private var viewModel: TripDetailsViewModel
    @EnvironmentObject var appState: WatchAppState
    
    let tripID: String
    let vehicleID: String?
    let routeShortName: String?
    let headsign: String?
    let initialTrip: OBATripForLocation?
    
    @State private var mapPosition: MapCameraPosition = .automatic
    
    private var resolvedGlyph: String {
        let text = "\(routeShortName ?? "") \(headsign ?? "")".lowercased()
        if text.contains("train") || text.contains("rail") || text.contains("subway") || text.contains("tram") || text.contains("link") {
            return "train.side.front.car"
        }
        return "bus.fill"
    }
    
    init(tripID: String, vehicleID: String? = nil, routeShortName: String? = nil, headsign: String? = nil, initialTrip: OBATripForLocation? = nil) {
        self.tripID = tripID
        self.vehicleID = vehicleID
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.initialTrip = initialTrip
        _viewModel = StateObject(wrappedValue: TripDetailsViewModel(
            apiClient: WatchAppState.shared.apiClient,
            tripID: tripID,
            vehicleID: vehicleID,
            initialTrip: initialTrip
        ))
    }
    
    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                mapSection
                
                if let details = viewModel.tripDetails {
                    headerSection(details)
                    vehicleStatusSection(details)
                    stopsSection(details)
                    adjacentTripsSection(details)
                }
            }
        }
        .navigationTitle(routeShortName ?? OBALoc("trip_details.title", value: "Trip Details", comment: "Trip details title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDetails()
            updateCameraPosition()
        }
        .onDisappear {
            viewModel.stopLiveTracking()
        }
        .onChange(of: viewModel.polyline.count) { _, newCount in
            if newCount > 0 {
                updateCameraPosition()
            }
        }
        .onChange(of: viewModel.vehicleLatitude) { _, newLat in
            if newLat != nil {
                updateCameraPosition()
            }
        }
    }

    private var mapSection: some View {
        Section {
            ZStack(alignment: .topLeading) {
                Map(position: $mapPosition) {
                    // Outer dark contrast casing
                    if !viewModel.polyline.isEmpty {
                        MapPolyline(coordinates: viewModel.polyline)
                            .stroke(Color.black.opacity(0.85), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                        
                        // Passed Route Segment (Muted Slate Gray)
                        if !viewModel.passedPolyline.isEmpty {
                            MapPolyline(coordinates: viewModel.passedPolyline)
                                .stroke(
                                    Color(red: 0.35, green: 0.45, blue: 0.58).opacity(0.75),
                                    style: StrokeStyle(lineWidth: 5.5, lineCap: .round, lineJoin: .round)
                                )
                        }
                        
                        // Upcoming Route Segment (Vibrant Mint Green)
                        if !viewModel.upcomingPolyline.isEmpty {
                            MapPolyline(coordinates: viewModel.upcomingPolyline)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0.0, green: 0.9, blue: 0.45), Color(red: 0.1, green: 0.98, blue: 0.55)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                                )
                        }
                    }
                    
                    // Stop Markers - Native MapKit Markers matching WatchInteractiveMapView style
                    if let schedule = viewModel.tripDetails?.schedule {
                        let isTrainMode = resolvedGlyph.contains("train")
                        ForEach(Array(schedule.stopTimes.enumerated()), id: \.offset) { _, st in
                            if let lat = st.latitude, let lon = st.longitude {
                                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                                Marker(
                                    st.stopHeadsign ?? "",
                                    systemImage: resolvedGlyph,
                                    coordinate: coord
                                )
                                .tint(isTrainMode ? .indigo : .blue)
                            }
                        }
                    }
                    
                    // Live Bus Vehicle Marker - Animated Blinking Radar Ring
                    if let coord = viewModel.vehicleCoordinate {
                        Annotation("", coordinate: coord, anchor: .center) {
                            PulsingVehicleMarker(
                                title: routeShortName ?? "Bus",
                                heading: viewModel.glider.currentHeading,
                                isTracked: true
                            )
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
                .id("standard")
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if let vCoord = viewModel.vehicleCoordinate {
                    HStack(spacing: 6) {
                        // Left circle badge
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12) )
                                .frame(width: 22, height: 22)
                            Image(systemName: resolvedGlyph)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        
                        // Middle text info
                        VStack(alignment: .leading, spacing: 0) {
                            Text(formattedDistance(latitude: vCoord.latitude, longitude: vCoord.longitude))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(headsign ?? routeShortName ?? "Live")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        // Direction Arrow (Live)
                        Image(systemName: "location.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.blue)
                            .rotationEffect(Angle(degrees: relativeBearing(lat: vCoord.latitude, lon: vCoord.longitude) - 45)) // location.fill points top-right (45 deg) by default
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1.5)
                    )
                    .padding(6)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func updateCameraPosition() {
        withAnimation {
            if let vCoord = viewModel.vehicleCoordinate {
                // Focus camera tightly on live bus location
                mapPosition = .region(MKCoordinateRegion(center: vCoord, latitudinalMeters: 600, longitudinalMeters: 600))
            } else if let region = computeBoundingRegion(coordinates: viewModel.polyline) {
                mapPosition = .region(region)
            }
        }
    }

    private func computeBoundingRegion(coordinates: [CLLocationCoordinate2D], vehicleCoordinate: CLLocationCoordinate2D? = nil) -> MKCoordinateRegion? {
        var allCoords = coordinates
        if let vehicle = vehicleCoordinate {
            allCoords.append(vehicle)
        }
        guard !allCoords.isEmpty else { return nil }
        
        var minLat = allCoords[0].latitude
        var maxLat = allCoords[0].latitude
        var minLon = allCoords[0].longitude
        var maxLon = allCoords[0].longitude
        
        for c in allCoords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        // Tight 1.1x padding so route fills maximum map frame
        let latDelta = max((maxLat - minLat) * 1.1, 0.003)
        let lonDelta = max((maxLon - minLon) * 1.1, 0.003)
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    private func findNextStopIndex(in stopTimes: [OBATripExtendedDetails.StopTime], vehicleDistance: Double, nextStopID: String?) -> Int? {
        if let nextStopID = nextStopID, !nextStopID.isEmpty {
            if let idx = stopTimes.firstIndex(where: { $0.stopId == nextStopID }) {
                return idx
            }
        }
        guard vehicleDistance > 0 else { return nil }
        for (idx, st) in stopTimes.enumerated() {
            let d = st.distanceAlongTrip ?? 0
            if d > vehicleDistance {
                return idx
            }
        }
        return nil
    }

    private func formattedTitle(for details: OBATripExtendedDetails) -> String {
        if let route = routeShortName, !route.isEmpty {
            if let dest = headsign, !dest.isEmpty {
                return "\(route) to \(dest)"
            }
            return String(format: OBALoc("common.route_fmt", value: "Route %@", comment: "Route name format"), route)
        }
        if let dest = headsign, !dest.isEmpty {
            return dest
        }
        return OBALoc("trip_details.title", value: "Trip Details", comment: "Trip details title")
    }

    private func formattedSubtitle(for details: OBATripExtendedDetails) -> String? {
        let rawID = details.tripId ?? tripID
        if !rawID.isEmpty {
            let cleanID = rawID.components(separatedBy: "_").last ?? rawID
            return String(format: OBALoc("trip_details.trip_id_fmt", value: "Trip ID: %@", comment: "Trip ID format"), cleanID)
        }
        return nil
    }

    private func headerSection(_ details: OBATripExtendedDetails) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedTitle(for: details))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if let sub = formattedSubtitle(for: details) {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let serviceDate = details.serviceDate {
                    HStack(spacing: 4) {
                        Text(serviceDate, style: .time)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(OBALoc("status.scheduled", value: "Scheduled", comment: "Scheduled status"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
        )
    }

    @ViewBuilder
    private func vehicleStatusSection(_ details: OBATripExtendedDetails) -> some View {
        if let status = details.status {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "bus.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        
                        if let vehicleID = status.vehicleID {
                            Text(String(format: OBALoc("trip_details.vehicle_fmt", value: "Vehicle %@", comment: "Vehicle format"), vehicleID))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        } else {
                            Text(OBALoc("trip_details.vehicle_status", value: "Vehicle Status", comment: "Vehicle status title"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        if let deviation = status.scheduleDeviation {
                            Text(deviationString(seconds: deviation))
                                .font(.system(size: 12))
                                .foregroundColor(deviationColor(seconds: deviation))
                        } else if status.predicted == true || status.lastUpdateTime != nil {
                            Text(OBALoc("status.on_time", value: "On time", comment: "On time status"))
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        } else {
                            Text(OBALoc("status.scheduled", value: "Scheduled", comment: "Scheduled status"))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        if (status.scheduleDeviation != nil || status.predicted != nil || status.lastUpdateTime != nil) && status.lastUpdateTime != nil {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        if let lastUpdate = status.lastUpdateTime {
                            Text(relativeTime(for: lastUpdate))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.12))
            )
        }
    }

    private func deviationColor(seconds: Int) -> Color {
        if seconds <= 0 { return .green }
        if seconds < 300 { return .yellow }
        return .red
    }

    @ViewBuilder
    private func stopsSection(_ details: OBATripExtendedDetails) -> some View {
        if let schedule = details.schedule {
            let nextStopId = viewModel.tripDetails?.status?.nextStop
            let nextStopIndex = schedule.stopTimes.firstIndex(where: { $0.stopId == nextStopId }) ?? -1
            
            Section(OBALoc("trip_details.section.stops", value: "Stops", comment: "Stops section header")) {
                ForEach(Array(schedule.stopTimes.enumerated()), id: \.offset) { index, stopTime in
                    let isVisited = nextStopIndex != -1 && index < nextStopIndex
                    
                    if let stopID = stopTime.stopId {
                        let arrivalSecs = stopTime.arrivalTime ?? stopTime.departureTime ?? 0
                        let arrDate = (details.serviceDate ?? Date()).addingTimeInterval(TimeInterval(arrivalSecs))
                        let context = TransferContext(
                            arrivalTime: arrDate,
                            fromRouteShortName: routeShortName ?? "",
                            fromTripHeadsign: headsign ?? ""
                        )
                        NavigationLink {
                            StopArrivalsView(stopID: stopID, transferContext: context)
                        } label: {
                            StopRow(
                                stopTime: stopTime,
                                isFirst: index == 0,
                                isLast: index == schedule.stopTimes.count - 1,
                                serviceDate: details.serviceDate,
                                nextStopId: nextStopId,
                                isVisited: isVisited,
                                resolvedGlyph: resolvedGlyph
                            )
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.12))
                        )
                    } else {
                        StopRow(
                            stopTime: stopTime,
                            isFirst: index == 0,
                            isLast: index == schedule.stopTimes.count - 1,
                            serviceDate: details.serviceDate,
                            nextStopId: nextStopId,
                            isVisited: isVisited,
                            resolvedGlyph: resolvedGlyph
                        )
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.12))
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func adjacentTripsSection(_ details: OBATripExtendedDetails) -> some View {
        if let schedule = details.schedule, (schedule.previousTripId != nil || schedule.nextTripId != nil) {
            Section {
                HStack(spacing: 8) {
                    if let prevID = schedule.previousTripId, !prevID.isEmpty {
                        NavigationLink {
                            TripDetailsView(tripID: prevID, routeShortName: routeShortName)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(OBALoc("trip_details.prev_trip", value: "Prev Trip", comment: "Previous trip button"))
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let nextID = schedule.nextTripId, !nextID.isEmpty {
                        NavigationLink {
                            TripDetailsView(tripID: nextID, routeShortName: routeShortName)
                        } label: {
                            HStack(spacing: 4) {
                                Text(OBALoc("trip_details.next_trip", value: "Next Trip", comment: "Next trip button"))
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
        }
    }
    
    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func deviationString(seconds: Int) -> String {
        let minutes = abs(seconds) / 60
        if seconds == 0 { return OBALoc("status.on_time", value: "On time", comment: "On time status") }
        let label = seconds > 0 ? OBALoc("status.late", value: "late", comment: "Late status") : OBALoc("status.early", value: "early", comment: "Early status")
        return "\(minutes)m \(label)"
    }
    
    private func formatTime(seconds: Int, serviceDate: Date?) -> String {
        let date = (serviceDate ?? Date()).addingTimeInterval(TimeInterval(seconds))
        return Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

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
}

struct StopRow: View {
    let stopTime: OBATripExtendedDetails.StopTime
    let isFirst: Bool
    let isLast: Bool
    let serviceDate: Date?
    let nextStopId: String?
    let isVisited: Bool
    let resolvedGlyph: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                let isVehicleApproaching = stopTime.stopId != nil && stopTime.stopId == nextStopId
                
                if !isFirst {
                    Rectangle()
                        .fill(isVisited ? Color.gray.opacity(0.3) : Color.green.opacity(0.5))
                        .frame(width: 2, height: 12)
                } else {
                    Color.clear.frame(width: 2, height: 12)
                }
                
                ZStack {
                    if isVehicleApproaching {
                        Circle()
                            .fill(Color(red: 0.0, green: 0.88, blue: 0.4))
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                        Image(systemName: resolvedGlyph)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    } else if isVisited {
                        Circle()
                            .fill(Color.gray.opacity(0.35))
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                        Circle()
                            .strokeBorder(Color.green, lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                }
                .frame(width: 20, height: 20)
                
                if !isLast {
                    Rectangle()
                        .fill((isVisited && !isVehicleApproaching) ? Color.gray.opacity(0.3) : Color.green.opacity(0.5))
                        .frame(width: 2)
                } else {
                    Color.clear.frame(width: 2)
                }
            }
            .frame(width: 20)
            
            // Content Card
             VStack(alignment: .leading, spacing: 2) {
                 HStack(alignment: .top) {
                    let displayName: String = {
                        if let name = stopTime.stopHeadsign, !name.isEmpty {
                            return name
                        }
                        let stopSuffix = stopTime.stopId?.components(separatedBy: "_").last ?? OBALoc("common.unknown", value: "Unknown", comment: "Unknown value")
                        return String(format: OBALoc("trip_details.stop_title_fmt", value: "Stop %@", comment: "Stop title format"), stopSuffix)
                    }()
                     
                     Text(displayName)
                         .font(.system(size: 15, weight: .semibold))
                         .foregroundColor(.white)
                         .lineLimit(2)
                         .fixedSize(horizontal: false, vertical: true)
                     
                     Spacer()
                     
                     if let arrival = stopTime.arrivalTime {
                         Text(formatTime(seconds: arrival, serviceDate: serviceDate))
                             .font(.system(size: 13, weight: .bold))
                             .foregroundColor(.green)
                     }
                 }
                 
                 HStack {
                     if let stopId = stopTime.stopId {
                         Text(String(format: OBALoc("trip_details.stop_id_format", value: "ID: %@", comment: "Stop ID format"), stopId.components(separatedBy: "_").last ?? stopId))
                             .font(.system(size: 11))
                             .foregroundColor(.secondary)
                     }
                     
                     if let distance = stopTime.distanceAlongTrip, distance > 0 {
                         Spacer()
                         Text(String(format: OBALoc("trip_details.distance_format", value: "%.1f mi", comment: "Distance format"), distance / 1609.34))
                             .font(.system(size: 11))
                             .foregroundColor(.secondary)
                     }
                 }
             }
             .padding(.vertical, 8)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
    }
    
    private func formatTime(seconds: Int, serviceDate: Date?) -> String {
        let date = (serviceDate ?? Date()).addingTimeInterval(TimeInterval(seconds))
        return Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
