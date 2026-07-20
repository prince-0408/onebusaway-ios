//
//  MainMenuView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

/// Main menu shown after permission has been handled.
struct MainMenuView: View {
    @EnvironmentObject var appState: WatchAppState
    @AppStorage("watch_selected_region_id", store: WatchAppState.userDefaults) private var selectedRegionID: String = "mta-new-york"
    /// Becomes true only after the debounce window closes without a successful sync,
    /// preventing a flash on normal fast launches.
    @State private var showTimeSyncWarning: Bool = false

    private var regionName: String {
        return appState.regions.first(where: { $0.id == selectedRegionID })?.name ?? OBALoc("common.app_name", value: "OneBusAway", comment: "The name of the application")
    }
    
    var body: some View {
        List {
            // Time sync warning — shown only if all retry attempts failed.
            if showTimeSyncWarning && !appState.timeSyncSucceeded {
                Section {
                    Button {
                        Task { await appState.syncTime() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(OBALoc("time_sync.warning.title", value: "Clock Sync Failed", comment: "Warning: time sync failed"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.yellow)
                                Text(OBALoc("time_sync.warning.subtitle", value: "Arrival times may be inaccurate. Tap to retry.", comment: "Warning subtitle for time sync failure"))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.12))
                )
            }

            // Search & Map at the top
            Section {
                NavigationLink {
                    SearchView()
                } label: {
                    Label(OBALoc("common.search", value: "Search", comment: "Title for search menu item"), systemImage: "magnifyingglass")
                        .font(.headline)
                }
            }

            Section {
                RegionPreviewMapView()
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .listRowInsets(EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2))
                    .listRowBackground(Color.clear)
            }

            // Bookmarks Section - Keep this because user asked to fix it!
            Section {
                NavigationLink {
                    BookmarksView()
                } label: {
                    Label(OBALoc("common.bookmarks", value: "Bookmarks", comment: "Title for bookmarks menu item"), systemImage: "bookmark.fill")
                        .foregroundColor(.blue)
                }
            }

            // Trip Planning Section - Make this prominent
            Section {
                NavigationLink {
                    TripPlanningEntryView()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(OBALoc("common.trip_planner", value: "Trip Planner", comment: "Title for trip planner menu item"), systemImage: "figure.walk")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text(OBALoc("main_menu.plan_your_journey", value: "Plan your journey", comment: "Subtitle for trip planner menu item"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(OBALoc("main_menu.section.plan", value: "Plan", comment: "Section header for planning"))
            }
            
            // Other useful actions but minimized
            Section {
                NavigationLink {
                    NearbyStopsView()
                } label: {
                    Label(OBALoc("common.nearby", value: "Nearby", comment: "Title for nearby stops menu item"), systemImage: "location.fill")
                }

                NavigationLink {
                    RecentStopsView()
                } label: {
                    Label(OBALoc("common.recents", value: "Recents", comment: "Title for recent stops menu item"), systemImage: "clock.fill")
                }
                
                NavigationLink {
                    VehiclesView()
                } label: {
                    Label(OBALoc("common.vehicles", value: "Vehicles", comment: "Title for vehicles menu item"), systemImage: "bus.fill")
                }
            } header: {
                Text(OBALoc("main_menu.section.explore", value: "Explore", comment: "Section header for explore"))
            }
        }
        .navigationTitle(regionName)
        .onAppear {
            // Show the warning only after a 15-second window, so it doesn't
            // flash briefly on fast connections where sync completes quickly.
            Task {
                do {
                    try await Task.sleep(nanoseconds: 15 * 1_000_000_000)
                    showTimeSyncWarning = true
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
        }
        .onChange(of: appState.timeSyncSucceeded) { _, succeeded in
            if succeeded { showTimeSyncWarning = false }
        }
    }
}
