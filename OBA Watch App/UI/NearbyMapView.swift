//
//  NearbyMapView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import MapKit
import CoreLocation
import OBAKitCore

/// Simple map-based view of nearby stops.
struct NearbyMapView: View {
    let stops: [OBAStop]
    let currentLocation: CLLocation?
    let mapStyle: MapStyle

    var body: some View {
        Map {
            UserAnnotation()
            
            ForEach(stops.prefix(20)) { stop in
                Marker(stop.name, systemImage: stop.iconName, coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
                    .tint(stop.isTrain ? .indigo : .brand)
            }
        }
        .mapStyle(mapStyle)
    }
}
