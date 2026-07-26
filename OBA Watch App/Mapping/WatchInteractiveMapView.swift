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
    
    @State private var mapPosition: MapCameraPosition
    @State private var selectedStop: OBAStop?
    @State private var showStopArrivals: Bool = false
    
    init(initialRegion: MKCoordinateRegion? = nil, stops: [OBAStop] = [], vehicles: [OBAVehicle] = []) {
        self.initialRegion = initialRegion
        self.stops = stops
        self.vehicles = vehicles
        
        if let reg = initialRegion {
            _mapPosition = State(initialValue: .region(reg))
        } else {
            let loc = WatchAppState.shared.effectiveLocation
            let reg = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 800, longitudinalMeters: 800)
            _mapPosition = State(initialValue: .region(reg))
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $mapPosition) {
                UserAnnotation()
                
                ForEach(stops) { stop in
                    if stop.latitude != 0.0 || stop.longitude != 0.0 {
                        let coord = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
                        Annotation(stop.name, coordinate: coord) {
                            Button {
                                selectedStop = stop
                                showStopArrivals = true
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 22, height: 22)
                                        .shadow(radius: 2)
                                    
                                    Image(systemName: stop.locationType == 1 ? "train.side.front.car" : "bus")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                ForEach(vehicles) { vehicle in
                    if let lat = vehicle.latitude, let lon = vehicle.longitude {
                        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        Annotation(vehicle.routeShortName ?? "Bus", coordinate: coord) {
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 24)
                                    .shadow(radius: 3)
                                
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .mapStyle(appState.mapStyle)
            .mapControls {
                MapCompass()
                MapUserLocationButton()
            }
            
            // Floating Recenter Button
            Button {
                let loc = appState.effectiveLocation
                withAnimation {
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
    }
}
