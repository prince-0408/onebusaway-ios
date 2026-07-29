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
    @AppStorage("watch_selected_region_id", store: WatchAppState.userDefaults) private var selectedRegionID: String = WatchAppState.defaultRegionID
    /// Becomes true only after the debounce window closes without a successful sync,
    /// preventing a flash on normal fast launches.
    @State private var showTimeSyncWarning: Bool = false
    @State private var activeAlarms: [WatchAlarmItem] = AlarmsSyncManager.shared.currentAlarms()

    private var regionName: String {
        let defaultAppName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "OneBusAway"
        return appState.regions.first(where: { $0.id == selectedRegionID })?.name ?? OBALoc("common.app_name", value: defaultAppName, comment: "The name of the application")
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

            // Active Proximity Alarm Banner
            if let activeAlarm = activeAlarms.first {
                Section {
                    NavigationLink {
                        LazyView(StopArrivalsView(stopID: activeAlarm.stopID, stopName: activeAlarm.headsign))
                    } label: {
                        activeAlarmBanner(for: activeAlarm)
                    }
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.orange.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                        )
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

            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label(OBALoc("common.settings", value: "Settings", comment: "Title for settings menu item"), systemImage: "gearshape")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle(regionName)
        .onAppear {
            activeAlarms = AlarmsSyncManager.shared.currentAlarms()
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
        .onReceive(NotificationCenter.default.publisher(for: AlarmsSyncManager.alarmsUpdatedNotification)) { _ in
            activeAlarms = AlarmsSyncManager.shared.currentAlarms()
        }
        .onChange(of: appState.timeSyncSucceeded) { _, succeeded in
            if succeeded { showTimeSyncWarning = false }
        }
    }

    @ViewBuilder
    private func activeAlarmBanner(for activeAlarm: WatchAlarmItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
                .padding(6)
                .background(Circle().fill(Color.orange.opacity(0.2)))
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(activeAlarm.routeShortName ?? OBALoc("common.bus", value: "Bus", comment: "Default bus label"))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if let headsign = activeAlarm.headsign, !headsign.isEmpty {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(headsign)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if let scheduled = activeAlarm.scheduledTime {
                    Text(scheduled, style: .relative)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
            }
            
            Spacer(minLength: 4)
            
            Button {
                WatchFeedbackGenerator.shared.click()
                withAnimation(.easeInOut(duration: 0.2)) {
                    AlarmsSyncManager.shared.removeAlarm(stopID: activeAlarm.stopID, routeShortName: activeAlarm.routeShortName)
                    AlarmHapticScheduler.shared.stopExtendedRuntimeSession()
                    activeAlarms = AlarmsSyncManager.shared.currentAlarms()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(4)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
