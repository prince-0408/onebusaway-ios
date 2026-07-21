//
//  StopArrivalsView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore
import WatchKit

struct StopArrivalsView: View {
    let stopID: OBAStopID
    let stopName: String?
    
    @StateObject private var viewModel: StopArrivalsViewModel
    @State private var showActions: Bool = false
    @State private var showNearbyStops: Bool = false
    @State private var infoMessage: String?
    @State private var showAllArrivals: Bool = false
    @State private var showStopDetails: Bool = false
    @State private var showStopSchedule: Bool = false
    @State private var showStopProblem: Bool = false
    
    init(stopID: OBAStopID, stopName: String? = nil) {
        print("[WatchOS Debug] StopArrivalsView.init called for stopID: \(stopID)")
        self.stopID = stopID
        self.stopName = stopName
        _viewModel = StateObject(wrappedValue: StopArrivalsViewModel(
            apiClientProvider: { WatchAppState.shared.apiClient },
            stopID: stopID
        ))
    }
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        if let stopName = viewModel.stopName ?? stopName {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stopName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Text(String(format: OBALoc("stop_arrivals.stop_id_fmt", value: "Stop %@", comment: "Stop ID format"), stopID))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button {
                            showActions = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.isOfflineMode {
                        HStack(spacing: 4) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                            Text(OBALoc("stop_arrivals.offline_cached", value: "Offline (Cached Schedule)", comment: "Offline cached schedule banner"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    } else if let updated = viewModel.lastUpdated {
                        Text(String(format: OBALoc("stop_arrivals.updated_fmt", value: "Updated: %@", comment: "Last updated time format"), relativeUpdateString(from: updated)))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
            )

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
                    ErrorView(message: error)
                }
                .listRowBackground(Color.clear)
            } else if viewModel.upcomingArrivals.isEmpty {
                Section {
                    EmptyArrivalsView()
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(displayedArrivals) { arrival in
                        NavigationLink {
                            ArrivalDetailView(arrival: arrival)
                        } label: {
                            ArrivalRowView(arrival: arrival)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    
                    if viewModel.upcomingArrivals.count > 5 {
                        Button(showAllArrivals ? OBALoc("common.show_fewer", value: "Show Fewer", comment: "Button to show fewer items") : OBALoc("common.load_more", value: "Load More", comment: "Button to load more items")) {
                            showAllArrivals.toggle()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .listRowBackground(Color.clear)
                    }
                }
            }

            if !viewModel.routes.isEmpty {
                Section(OBALoc("common.routes", value: "Routes", comment: "Section title for routes")) {
                    ForEach(viewModel.routes) { route in
                        HStack(spacing: 12) {
                            Text(route.shortName ?? "??")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.blue.gradient)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.longName ?? OBALoc("common.unknown_route", value: "Unknown Route", comment: "Fallback text for unknown route name"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                if let agency = route.agencyName {
                                    Text(agency)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                }
            }
            
            // Hidden navigation links for sheet actions
        }
        .navigationTitle(OBALoc("stop_arrivals.title", value: "Arrivals", comment: "Title for stop arrivals screen"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNearbyStops) {
            NavigationStack {
                NearbyStopsView()
            }
        }
        .sheet(isPresented: $showStopDetails) {
            NavigationStack {
                StopDetailView(stopID: stopID)
            }
        }
        .sheet(isPresented: $showStopSchedule) {
            NavigationStack {
                StopScheduleView(stopID: stopID)
            }
        }
        .sheet(isPresented: $showStopProblem) {
            NavigationStack {
                ProblemReportView(mode: .stop(stopID: stopID))
            }
        }
        .refreshable {
            await viewModel.loadArrivals()
            WatchFeedbackGenerator.shared.success()
        }
        .sheet(isPresented: $showActions) {
            List {
                Section {
                    Button(OBALoc("common.refresh", value: "Refresh", comment: "Refresh button")) {
                        showActions = false
                        Task {
                            await viewModel.loadArrivals()
                            WatchFeedbackGenerator.shared.success()
                        }
                    }
                    Button(OBALoc("stop_details.title", value: "Stop Details", comment: "Title for stop details screen")) {
                        showActions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showStopDetails = true
                        }
                    }
                    Button(OBALoc("common.schedules", value: "Schedules", comment: "Action to view schedules")) {
                        showActions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showStopSchedule = true
                        }
                    }
                    Button(OBALoc("common.nearby_stops", value: "Nearby Stops", comment: "Action to view nearby stops")) {
                        showActions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showNearbyStops = true
                        }
                    }
                    Button(OBALoc("problem_report.title", value: "Report a Problem", comment: "Action to report a problem")) {
                        showActions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showStopProblem = true
                        }
                    }
                    Button(OBALoc("common.open_on_iphone", value: "Open on iPhone", comment: "Action to open the stop on iPhone")) {
                        showActions = false
                        let ok = DeepLinkSyncManager.shared.openStopOnPhone(stopID: stopID)
                        if !ok {
                            infoMessage = OBALoc("deeplink.failure", value: "Unable to contact iPhone. Make sure your devices are connected.", comment: "Deep link failure")
                        }
                    }
                }

                Section {
                    Button(OBALoc("common.close", value: "Close", comment: "Action to close a sheet"), role: .cancel) {
                        showActions = false
                    }
                }
            }
        }
        .alert(OBALoc("common.info", value: "Info", comment: "Alert title for information"), isPresented: Binding(
            get: { infoMessage != nil },
            set: { newValue in
                if !newValue { infoMessage = nil }
            }
        )) {
            Button(OBALoc("common.ok", value: "OK", comment: "OK button"), role: .cancel) { }
        } message: {
            Text(infoMessage ?? "")
        }
        .userActivity("org.onebusaway.iphone.user_activity.stop") { userActivity in
            userActivity.title = stopName ?? "Stop \(stopID)"
            userActivity.userInfo = ["stop_id": stopID]
            userActivity.isEligibleForHandoff = true
        }
        .onAppear {
            print("[WatchOS Debug] StopArrivalsView.onAppear called for stopID: \(stopID)")
        }
        .onDisappear {
            print("[WatchOS Debug] StopArrivalsView.onDisappear called for stopID: \(stopID)")
            viewModel.cancelRefresh()
        }
    }

    private var displayedArrivals: [OBAArrival] {
        if showAllArrivals {
            return viewModel.upcomingArrivals
        } else {
            return Array(viewModel.upcomingArrivals.prefix(5))
        }
    }

    private func relativeUpdateString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 30 {
            return OBALoc("times.just_now", value: "Just now", comment: "Time elapsed: just now")
        } else if interval < 60 {
            return OBALoc("times.less_than_minute_ago", value: "Less than a minute ago", comment: "Time elapsed: less than a minute")
        } else {
            let minutes = Int(interval / 60)
            if minutes == 1 {
                return OBALoc("times.one_minute_ago", value: "1 minute ago", comment: "Time elapsed: 1 minute")
            } else {
                return String(format: OBALoc("times.minutes_ago_fmt", value: "%d minutes ago", comment: "Time elapsed: multiple minutes"), minutes)
            }
        }
    }
}

struct ArrivalRowView: View {
    let arrival: OBAArrival
    
    var body: some View {
        HStack(spacing: 8) {
            // Route badge
            Text(arrival.routeShortName ?? "?")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(minWidth: 38)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(routeColor)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(arrival.headsign ?? OBALoc("common.unknown", value: "Unknown", comment: "Unknown value"))
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if arrival.isPredicted {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.green)
                    }
                    Text(arrival.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let statusLabel = arrival.scheduleStatusLabel {
                        Text(statusLabel)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()

            if arrival.hasServiceAlert {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var routeColor: Color {
        // Use a consistent color based on route ID
        let hash = abs(arrival.routeID.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
}



extension OBAArrival {
    /// Formatted time string for the arrival (e.g. "Now", "5 min", "1.2 h")
    var timeString: String {
        let minutes = self.minutesFromNow
        if minutes <= 0 {
            return OBALoc("times.now", value: "Now", comment: "Time: now")
        } else if minutes < 60 {
            return String(format: OBALoc("times.minutes_short_fmt", value: "%d min", comment: "Time: minutes short format"), minutes)
        } else {
            let hours = Double(minutes) / 60.0
            return String(format: OBALoc("times.hours_short_fmt", value: "%.1f h", comment: "Time: hours short format"), hours)
        }
    }
}

struct EmptyArrivalsView: View {
    var body: some View {
        EmptyStateView(
            systemImage: "clock.badge.xmark",
            title: OBALoc("stop_arrivals.no_upcoming_arrivals", value: "No Upcoming Arrivals", comment: "Empty state: no upcoming arrivals"),
            message: OBALoc("stop_arrivals.check_back_later", value: "Check back later", comment: "Empty state: check back later")
        )
    }
}


#Preview {
    NavigationStack {
        StopArrivalsView(stopID: "1_12345", stopName: "Preview Stop")
    }
}
