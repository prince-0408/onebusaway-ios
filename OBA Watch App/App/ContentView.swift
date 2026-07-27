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
    
    // Deep Link states
    @State private var activeStopID: OBAStopID?
    @State private var activeStopName: String?
    
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
            .navigationTitle(OBALoc("common.app_name", value: Bundle.main.appName, comment: "The name of the application"))
            .navigationDestination(item: $activeStopID) { stopID in
                StopArrivalsView(stopID: stopID, stopName: activeStopName)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "onebusaway" else { return }
            if url.host == "stop" {
                let stopID = url.lastPathComponent
                if !stopID.isEmpty {
                    self.activeStopName = url.queryParameters?["name"] ?? "Stop \(stopID)"
                    self.activeStopID = stopID
                }
            } else if url.host == "region" {
                let regionID = url.lastPathComponent
                if !regionID.isEmpty {
                    WatchAppState.userDefaults.set(regionID, forKey: "watch_selected_region_id")
                    WatchAppState.userDefaults.synchronize()
                }
            }
        }
    }
}

private extension Bundle {
    var appName: String {
        return (object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "OneBusAway"
    }
}

private extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems else { return nil }
        return queryItems.reduce(into: [String: String]()) { dict, item in
            dict[item.name] = item.value
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchAppState.shared)
}
