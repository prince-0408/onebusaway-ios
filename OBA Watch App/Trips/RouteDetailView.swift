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

        let center: CLLocationCoordinate2D
        if let firstVehicle = vehicleCoordinates.first {
            center = firstVehicle
        } else if let first = coordinates.first {
            center = first
        } else {
            center = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        _mapPosition = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )))
    }

    var body: some View {
        Map(position: $mapPosition) {
            if !coordinates.isEmpty {
                MapPolyline(coordinates: coordinates)
                    .stroke(.green, lineWidth: 3)
            }
            
            if !vehicleCoordinates.isEmpty {
                ForEach(0..<vehicleCoordinates.count, id: \.self) { idx in
                    Annotation("", coordinate: vehicleCoordinates[idx]) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 22, height: 22)
                                .shadow(radius: 3)
                            
                            Image(systemName: "bus.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
            } else {
                let sampleCount = 3
                let step = max(1, coordinates.count / (sampleCount + 1))
                let sampleIndices = (1...sampleCount).map { $0 * step }.filter { $0 < coordinates.count }
                
                ForEach(sampleIndices, id: \.self) { index in
                    Annotation("", coordinate: coordinates[index]) {
                        ZStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 20, height: 20)
                                .shadow(radius: 2)
                            
                            Image(systemName: "bus.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .mapStyle(mapStyle)
    }
}

private struct RouteShapePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
