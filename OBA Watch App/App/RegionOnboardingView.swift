//
//  RegionOnboardingView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import MapKit
import OBAKitCore

/// Second step of onboarding: lets the user pick a service region in a
/// watch-appropriate way, inspired by the iOS "Choose Region" screen.
struct RegionOnboardingView: View {
    @EnvironmentObject var appState: WatchAppState
    
    @AppStorage("watch_selected_region_id", store: WatchAppState.userDefaults) private var selectedRegionID: String = "mta-new-york"
    @AppStorage("watch_share_current_location", store: WatchAppState.userDefaults) private var shareCurrentLocation: Bool = true

    let onContinue: () -> Void

    @State private var mapRegion: MKCoordinateRegion

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        
        // Use the saved region if available, otherwise fall back to MTA New York.
        let savedRegionID = WatchAppState.userDefaults.string(forKey: "watch_selected_region_id") ?? "mta-new-york"
        
        let region = WatchAppState.shared.regions.first(where: { $0.id == savedRegionID })
        let initialCoordinate = region?.coordinate ?? CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
        ))
    }

    var body: some View {
        List {
            Section {
                Toggle(isOn: $shareCurrentLocation) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.green)
                        Text(OBALoc("region_onboarding.share_location", value: "Share Current Location", comment: "Option to share current location"))
                            .font(.headline)
                    }
                }
            }

            Section {
                ForEach(appState.regions.filter { $0.obaBaseURL != nil }) { region in
                    Button {
                        appState.updateRegion(id: region.id)
                        mapRegion.center = region.coordinate
                    } label: {
                        HStack {
                            Text(region.name)
                            Spacer()
                            if region.id == selectedRegionID {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            Section {
                Map(coordinateRegion: $mapRegion)
                    .frame(maxWidth: .infinity, minHeight: 140, maxHeight: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                    .listRowBackground(Color.clear)
            }

            Section {
                Button(action: onContinue) {
                    Text(OBALoc("common.continue", value: "Continue", comment: "Button title to continue"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .modifier(GlassCapsuleModifier())
                .foregroundStyle(shareCurrentLocation ? Color.green : Color.gray)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
            }
        }
    }
}
