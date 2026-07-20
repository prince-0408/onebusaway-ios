//
//  LocationOnboardingView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import CoreLocation
import OBAKitCore

/// Simple first-run screen that encourages the user to enable location
/// so that Nearby Stops works as expected.
struct LocationOnboardingView: View {
    @EnvironmentObject var appState: WatchAppState
    
    var body: some View {
        VStack(spacing: 0) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 52, height: 52)
                .cornerRadius(12)
                .shadow(color: .green.opacity(0.3), radius: 4)
                .padding(.top, 24)
            
            VStack(spacing: 2) {
                Text(OBALoc("location_onboarding.nearby_transit", value: "Nearby Transit", comment: "Title for the location onboarding screen"))
                    .font(.system(size: 17, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(OBALoc("location_onboarding.description", value: "Find stops and schedules based on where you are.", comment: "Description for the location onboarding screen"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            
            Spacer(minLength: 4)
            
            Button {
                appState.requestLocationPermission()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))

                    Text(OBALoc("location_onboarding.allow_access", value: "Allow Access", comment: "Button title to request location permission"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(Color.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .modifier(GlassCapsuleModifier())
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .containerBackground(Color.black.gradient, for: .navigation)
    }
}
