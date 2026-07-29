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
    @State private var isStopBookmarked = false
    @State private var showAlarmSetup = false
    
    init(stopID: OBAStopID, stopName: String? = nil, transferContext: TransferContext? = nil) {
        self.stopID = stopID
        self.stopName = stopName
        _viewModel = StateObject(wrappedValue: StopArrivalsViewModel(
            apiClientProvider: { WatchAppState.shared.apiClient },
            stopID: stopID,
            transferContext: transferContext
        ))
    }
    
    var body: some View {
        List {
            if let transferContext = viewModel.transferContext {
                Section {
                    TransferBannerView(
                        context: transferContext,
                        stopName: viewModel.stopName ?? stopName,
                        connectingArrival: viewModel.arrivals.first
                    )
                }
                .listRowBackground(Color.clear)
            }

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
                        HStack(spacing: 8) {
                            Button {
                                withAnimation {
                                    viewModel.sortMode = (viewModel.sortMode == .byTime ? .byRoute : .byTime)
                                }
                            } label: {
                                Image(systemName: viewModel.sortMode == .byTime ? "arrow.up.arrow.down.circle" : "arrow.up.arrow.down.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            Button {
                                toggleStopBookmark()
                            } label: {
                                Image(systemName: isStopBookmarked ? "star.fill" : "star")
                                    .font(.system(size: 18))
                                    .foregroundColor(.yellow)
                            }
                            .buttonStyle(.plain)

                            Button {
                                showActions = true
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
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
                        HStack(spacing: 4) {
                            Text(String(format: OBALoc("stop_arrivals.updated_fmt", value: "Updated: %@", comment: "Last updated time format"), relativeUpdateString(from: updated)))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            let userLoc = WatchAppState.shared.effectiveLocation
                            if let lat = viewModel.stopLatitude, let lon = viewModel.stopLongitude, lat != 0.0 || lon != 0.0 {
                                let stopLoc = CLLocation(latitude: lat, longitude: lon)
                                if let walkInfo = WalkTimeInfo.compute(from: userLoc, to: stopLoc) {
                                    Text("•")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                    Text(walkInfo.formattedWalkTime)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                )

                if viewModel.availableRouteFilters.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Button {
                                viewModel.selectedRouteFilter = nil
                            } label: {
                                Text(OBALoc("common.all", value: "All", comment: "All filter button"))
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(viewModel.selectedRouteFilter == nil ? Color.blue : Color.white.opacity(0.15))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            ForEach(viewModel.availableRouteFilters, id: \.self) { routeFilter in
                                Button {
                                    if viewModel.selectedRouteFilter == routeFilter {
                                        viewModel.selectedRouteFilter = nil
                                    } else {
                                        viewModel.selectedRouteFilter = routeFilter
                                    }
                                } label: {
                                    Text(routeFilter)
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(viewModel.selectedRouteFilter == routeFilter ? Color.blue : Color.white.opacity(0.15))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                }
            }

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
            } else if displayedArrivals.isEmpty {
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
                            ArrivalRowView(
                                arrival: arrival,
                                relativeTransferInfo: viewModel.relativeTransferInfo(for: arrival)
                            )
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
                        RoutePreferenceRowView(route: route, stopID: stopID)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
            
            hiddenRoutesSection
        }
        .navigationTitle(OBALoc("stop_arrivals.title", value: "Arrivals", comment: "Title for stop arrivals screen"))
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
                    Button(viewModel.sortMode == .byTime ? OBALoc("stop_arrivals.sort_toggle_route", value: "Sort: By Route", comment: "Toggle sort to by route") : OBALoc("stop_arrivals.sort_toggle_time", value: "Sort: By Time", comment: "Toggle sort to by time")) {
                        viewModel.sortMode = (viewModel.sortMode == .byTime ? .byRoute : .byTime)
                        showActions = false
                    }
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
                    Button(OBALoc("alarms.set_alarm", value: "Set Proximity Alarm", comment: "Set proximity alarm")) {
                        showActions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showAlarmSetup = true
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
        .onDisappear {
            // Cancel immediately so no in-flight network work blocks the
            // back-button pop animation on the main actor.
            viewModel.cancelRefresh()
        }
        .onAppear {
            isStopBookmarked = BookmarksSyncManager.shared.isBookmarked(stopID: stopID, routeShortName: nil)
            // Restart the refresh loop if the view reappears (e.g. swipe-back cancelled).
            if viewModel.arrivals.isEmpty {
                viewModel.startRefreshLoop()
            }
        }
        .sheet(isPresented: $showAlarmSetup) {
            NavigationStack {
                AlarmSetupView(
                    stopID: stopID,
                    stopName: viewModel.stopName ?? stopName,
                    routeShortName: nil,
                    headsign: nil,
                    departureTime: viewModel.upcomingArrivals.first?.arrivalTime,
                    latitude: viewModel.stopLatitude,
                    longitude: viewModel.stopLongitude
                )
            }
        }
    }

    @ViewBuilder
    private var hiddenRoutesSection: some View {
        let prefs = StopPreferencesStore.shared.preferences(for: stopID)
        if prefs.hasHiddenRoutes {
            Section(OBALoc("stop_preferences.hidden_routes", value: "Hidden Routes", comment: "Section title for hidden routes")) {
                Button {
                    StopPreferencesStore.shared.unhideAllRoutes(stopID: stopID)
                } label: {
                    HStack {
                        Image(systemName: "eye")
                            .foregroundColor(.blue)
                        Text(OBALoc("stop_preferences.unhide_all", value: "Unhide All Routes", comment: "Unhide all routes button"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
    }

    private var displayedArrivals: [OBAArrival] {
        let source = viewModel.upcomingFilteredArrivals
        if showAllArrivals {
            return source
        } else {
            return Array(source.prefix(5))
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

    private func toggleStopBookmark() {
        if isStopBookmarked {
            BookmarksSyncManager.shared.removeBookmark(stopID: stopID, routeShortName: nil)
            isStopBookmarked = false
        } else {
            let bookmark = WatchBookmark(
                id: UUID(),
                stopID: stopID,
                name: viewModel.stopName ?? stopName ?? "Stop \(stopID)",
                routeShortName: nil,
                tripHeadsign: nil
            )
            BookmarksSyncManager.shared.addBookmark(bookmark)
            isStopBookmarked = true
        }
        WatchFeedbackGenerator.shared.success()
    }
}

struct ArrivalRowView: View {
    let arrival: OBAArrival
    var relativeTransferInfo: (text: String, isMissed: Bool)? = nil
    
    @State private var showAlertSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Header: Route Pill + Headsign + Service Alert Icon
            HStack(alignment: .center, spacing: 6) {
                // Route badge
                Text(arrival.routeShortName ?? "?")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(routeColor)
                    )
                    .layoutPriority(2)
                
                Text(arrival.headsign ?? OBALoc("common.unknown", value: "Unknown", comment: "Unknown value"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .layoutPriority(1)
                
                Spacer(minLength: 0)
                
                if arrival.hasServiceAlert {
                    Button {
                        showAlertSheet = true
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.yellow)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Timing & Schedule Status Row
            HStack(alignment: .center, spacing: 4) {
                if arrival.isPredicted {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.green)
                }
                
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let mins = arrival.minutesFromNow(at: context.date)
                    Text(arrival.timeString(at: context.date))
                        .font(.system(size: 14, weight: mins <= 1 ? .bold : .semibold, design: .rounded))
                        .foregroundColor(mins <= 1 ? .green : (arrival.isPredicted ? .green : .primary))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer(minLength: 4)
                
                if let statusLabel = arrival.scheduleStatusLabel {
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            // Transfer / Occupancy info row (if present)
            if relativeTransferInfo != nil || arrival.occupancyEnum != nil {
                HStack(spacing: 6) {
                    if let relativeInfo = relativeTransferInfo {
                        Text(relativeInfo.text)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(relativeInfo.isMissed ? Color.red.opacity(0.2) : Color.green.opacity(0.2))
                            .foregroundColor(relativeInfo.isMissed ? .red : .green)
                            .cornerRadius(6)
                    }

                    WatchOccupancyStatusView(occupancyStatus: arrival.occupancyEnum, realtimeData: arrival.isPredicted)
                }
            }
        }
        .padding(.vertical, 3)
        .sheet(isPresented: $showAlertSheet) {
            NavigationStack {
                ServiceAlertDetailView(alert: WatchServiceAlert(
                    id: arrival.id,
                    title: arrival.alertTitle ?? OBALoc("alerts.service_advisory", value: "Service Advisory", comment: "Service advisory title"),
                    body: arrival.alertDescription,
                    severity: "WARNING",
                    affectedRoutes: arrival.routeShortName != nil ? [arrival.routeShortName!] : nil
                ))
            }
        }
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

struct RoutePreferenceRowView: View {
    let route: OBARoute
    let stopID: OBAStopID
    @State private var isHidden: Bool = false

    var body: some View {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            let labelText = isHidden ? OBALoc("stop_preferences.show", value: "Show", comment: "Show route") : OBALoc("stop_preferences.hide", value: "Hide", comment: "Hide route")
            let iconName = isHidden ? "eye" : "eye.slash"
            Button {
                StopPreferencesStore.shared.toggleRouteHidden(stopID: stopID, routeID: route.id)
                isHidden.toggle()
            } label: {
                Label(labelText, systemImage: iconName)
            }
            .tint(isHidden ? .blue : .orange)
        }
        .onAppear {
            isHidden = StopPreferencesStore.shared.isRouteHidden(stopID: stopID, routeID: route.id)
        }
    }
}

#Preview {
    NavigationStack {
        StopArrivalsView(stopID: "1_12345", stopName: "Preview Stop")
    }
}
