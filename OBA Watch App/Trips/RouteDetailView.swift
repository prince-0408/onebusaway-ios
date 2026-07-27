import SwiftUI
import MapKit
import OBAKitCore

struct RouteDetailView: View {
    let route: OBARoute

    @StateObject private var viewModel: RouteDetailViewModel
    @EnvironmentObject var appState: WatchAppState

    init(route: OBARoute) {
        self.route = route
        _viewModel = StateObject(wrappedValue: RouteDetailViewModel(
            apiClient: WatchAppState.shared.apiClient,
            routeID: route.id
        ))
    }

    var body: some View {
        List {
            if !viewModel.shapeCoordinates.isEmpty {
                RouteShapeMapView(
                    coordinates: viewModel.shapeCoordinates,
                    vehicleCoordinates: viewModel.vehicleCoordinates,
                    mapStyle: appState.mapStyle
                )
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if let alert = viewModel.serviceAlerts.first {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.yellow)
                            Text(alert.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                        }
                        if let body = alert.body, !body.isEmpty {
                            Text(body)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(3)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.2))
                )
            }

            if viewModel.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            } else if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            } else if !viewModel.directions.isEmpty {
                ForEach(viewModel.directions, id: \.id) { direction in
                    Section(direction.name ?? OBALoc("route_detail.section.direction", value: "Direction", comment: "Direction section header")) {
                        ForEach(direction.stops, id: \.id) { stop in
                            NavigationLink {
                                LazyView(StopArrivalsView(stopID: stop.id, stopName: stop.name))
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "signpost.right.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Color.green.gradient)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(stop.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        
                                        if let code = stop.code, !code.isEmpty {
                                            Text(String(format: OBALoc("route_detail.stop_format", value: "Stop %@", comment: "Stop code format"), code))
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }

                                        if let routesStr = stop.routeNames, !routesStr.isEmpty {
                                            let transfers = routesStr.components(separatedBy: ",")
                                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                                .filter { !$0.isEmpty && $0 != route.shortName }

                                            if !transfers.isEmpty {
                                                HStack(spacing: 3) {
                                                    Text(OBALoc("route_detail.transfers", value: "Transfers:", comment: "Transfers label"))
                                                        .font(.system(size: 9))
                                                        .foregroundColor(.secondary)

                                                    ForEach(transfers.prefix(4), id: \.self) { transferRoute in
                                                        Text(transferRoute)
                                                            .font(.system(size: 9, weight: .bold))
                                                            .padding(.horizontal, 4)
                                                            .padding(.vertical, 1)
                                                            .background(Color.blue.opacity(0.3))
                                                            .foregroundColor(.white)
                                                            .cornerRadius(4)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(route.shortName ?? OBALoc("route_detail.nav_title", value: "Route", comment: "Route detail navigation title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }
}

struct RouteShapeMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    let vehicleCoordinates: [CLLocationCoordinate2D]
    let mapStyle: MapStyle

    @State private var mapPosition: MapCameraPosition

    init(coordinates: [CLLocationCoordinate2D], vehicleCoordinates: [CLLocationCoordinate2D] = [], mapStyle: MapStyle = .standard) {
        self.coordinates = coordinates
        self.vehicleCoordinates = vehicleCoordinates
        self.mapStyle = mapStyle

        let region = Self.calculateRegion(coordinates: coordinates, vehicleCoordinates: vehicleCoordinates)
        _mapPosition = State(initialValue: .region(region))
    }

    var body: some View {
        Map(position: $mapPosition) {
            if !coordinates.isEmpty {
                // Outer dark casing stroke for high contrast
                MapPolyline(coordinates: coordinates)
                    .stroke(Color.black.opacity(0.85), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))

                // Inner vibrant mint green polyline
                MapPolyline(coordinates: coordinates)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.0, green: 0.9, blue: 0.45), Color(red: 0.1, green: 0.98, blue: 0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
                    )

                // Start & End Terminals along route shape
                if let start = coordinates.first {
                    Annotation("", coordinate: start, anchor: .center) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.8)).frame(width: 14, height: 14)
                            Circle().fill(Color.white).frame(width: 11, height: 11)
                            Circle().fill(Color(red: 0.0, green: 0.85, blue: 0.35)).frame(width: 6, height: 6)
                        }
                    }
                }
                if let end = coordinates.last, coordinates.count > 1 {
                    Annotation("", coordinate: end, anchor: .center) {
                        ZStack {
                            Circle().fill(Color.black.opacity(0.8)).frame(width: 14, height: 14)
                            Circle().fill(Color.white).frame(width: 11, height: 11)
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                        }
                    }
                }
            }

            if !vehicleCoordinates.isEmpty {
                ForEach(0..<vehicleCoordinates.count, id: \.self) { idx in
                    Annotation("", coordinate: vehicleCoordinates[idx], anchor: .center) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.0, green: 0.85, blue: 0.35).opacity(0.3))
                                .frame(width: 26, height: 26)
                            Circle()
                                .fill(Color(red: 0.0, green: 0.82, blue: 0.35))
                                .frame(width: 20, height: 20)
                                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                            Image(systemName: "bus.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
    }

    private static func calculateRegion(coordinates: [CLLocationCoordinate2D], vehicleCoordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var allCoords = coordinates + vehicleCoordinates
        if allCoords.isEmpty {
            return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        }
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
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2.0, longitude: (minLon + maxLon) / 2.0)
        let latDelta = max((maxLat - minLat) * 1.35, 0.008)
        let lonDelta = max((maxLon - minLon) * 1.35, 0.008)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}

private struct RouteShapePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
