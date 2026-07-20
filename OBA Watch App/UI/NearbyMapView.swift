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
                let icon = stop.locationType == 1 ? "train.side.front.car" : "bus"
                Marker(stop.name, systemImage: icon, coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
                    .tint(.green)
            }
        }
        .mapStyle(mapStyle)
    }
}
