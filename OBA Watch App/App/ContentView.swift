//
//  ContentView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

struct ContentView: View {
    @EnvironmentObject var appState: WatchAppState
    @AppStorage("watch_has_completed_region_onboarding", store: WatchAppState.userDefaults) private var hasCompletedRegionOnboarding: Bool = false
    @State private var showingMore = false
    
    var body: some View {
        NavigationStack {
            Group {
                if appState.authorizationStatus == .notDetermined {
                    LocationOnboardingView()
                } else if !hasCompletedRegionOnboarding {
                    RegionOnboardingView(onContinue: {
                        hasCompletedRegionOnboarding = true
                    })
                } else {
                    MainMenuView()
                }
            }
            .navigationTitle(OBALoc("common.app_name", value: "OneBusAway", comment: "The name of the application"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingMore = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingMore) {
                MoreView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchAppState.shared)
}
