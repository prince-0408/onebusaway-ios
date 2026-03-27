//
//  StopDetailView.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import SwiftUI
import OBAKitCore
import CoreLocation

// MARK: - StopDetailView

/// SwiftUI replacement for StopViewController's list UI.
/// Hosted via UIHostingController in StopViewController (thin UIKit wrapper).
struct StopDetailView: View {

    @ObservedObject var viewModel: StopDetailViewModel

    // Navigation callbacks wired by the hosting UIViewController
    var onSelectArrivalDeparture: ((ArrivalDeparture) -> Void)?
    var onAddBookmarkForStop: (() -> Void)?
    var onAddBookmarkForArrivalDeparture: ((ArrivalDeparture) -> Void)?
    var onAddAlarm: ((ArrivalDeparture) -> Void)?
    var onShowScheduleForStop: (() -> Void)?
    var onShowScheduleForRoute: ((ArrivalDeparture) -> Void)?
    var onShowServiceAlerts: (() -> Void)?
    var onShowNearbyStops: (() -> Void)?
    var onShowReportProblem: (() -> Void)?
    var onShowFilter: (() -> Void)?
    var onShowDonations: (() -> Void)?
    var onDismissDonations: (() -> Void)?
    var onSurveyAnswer: ((Survey, String) -> Void)?
    var onSurveyDismiss: ((Survey) -> Void)?
    var onShareTripStatus: ((ArrivalDeparture) -> Void)?

    var body: some View {
        ZStack(alignment: .top) {
            listContent
            // "Updated X ago" floating status capsule
            if !viewModel.statusText.isEmpty {
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.top, 4)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
            }
        }
        .task { await viewModel.loadData() }
    }

    // MARK: - List

    private var listContent: some View {
        List {
            // Stop header
            if let stop = viewModel.stop {
                StopDetailHeaderView(stop: stop)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            if !viewModel.isPreviewMode {
                // Broken bookmark error state
                if viewModel.isBrokenBookmark {
                    brokenBookmarkView
                }

                // Survey banner
                if let survey = viewModel.currentSurvey {
                    surveyBanner(survey)
                }

                // Donations banner
                if viewModel.shouldShowDonations {
                    donationsBanner
                }

                // Service alerts (collapsible, persisted)
                if !viewModel.serviceAlerts.isEmpty {
                    serviceAlertsBanner
                }
            }

            // Arrival/departure sections
            ForEach(viewModel.sections) { section in
                arrivalDepartureSection(section)
            }

            if !viewModel.isPreviewMode {
                // Inline error above Load More (non-fatal, list still visible)
                if let inlineError = viewModel.inlineError {
                    inlineErrorRow(inlineError)
                }

                // Load more
                loadMoreButton

                // Data attribution
                if let stop = viewModel.stop {
                    dataAttributionFooter(stop: stop)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.loadData() }
        .overlay {
            if let error = viewModel.error, !viewModel.isLoading {
                errorView(error)
            }
        }
    }

    // MARK: - Broken Bookmark

    private var brokenBookmarkView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bookmark.slash.fill")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Broken Bookmark")
                .font(.headline)
            Text(OBALoc("stop_controller.bad_bookmark_error_message",
                        value: "This bookmark may not work anymore. Did your transit agency change something? Please delete and recreate the bookmark.",
                        comment: ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Survey Banner

    private func surveyBanner(_ survey: Survey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !survey.study.name.isEmpty {
                Text(survey.study.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            if let heroQuestion = survey.heroQuestion {
                Text(heroQuestion.content.labelText)
                    .font(.subheadline.weight(.medium))
                if let options = heroQuestion.content.options {
                    ForEach(options, id: \.self) { option in
                        Button {
                            onSurveyAnswer?(survey, option)
                        } label: {
                            Text(option)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Button(OBALoc("common.dismiss", value: "Dismiss", comment: "")) {
                onSurveyDismiss?(survey)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Donations Banner

    private var donationsBanner: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.pink.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: "heart.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.pink)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Support OneBusAway")
                    .font(.subheadline.weight(.semibold))
                Text("Help keep this app running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Donate") { onShowDonations?() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.pink)
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDismissDonations?() } label: {
                Label("Dismiss", systemImage: "xmark")
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Service Alerts Banner

    private var serviceAlertsBanner: some View {
        Button { onShowServiceAlerts?() } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("\(viewModel.serviceAlerts.count) Service Alert\(viewModel.serviceAlerts.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
        .accessibilityLabel(Text("Service alerts, \(viewModel.serviceAlerts.count) alert\(viewModel.serviceAlerts.count == 1 ? "" : "s")"))
        .accessibilityHint(Text("Tap to view service alerts for this stop"))
    }

    // MARK: - Arrival/Departure Section

    @ViewBuilder
    private func arrivalDepartureSection(_ section: ArrivalDepartureSection) -> some View {
        let isCollapsed = viewModel.isSectionCollapsed(section.id)
        let banner = (!section.isPast && viewModel.sortType == .time)
            ? viewModel.walkTimeBanner(rows: section.rows)
            : nil

        Section {
            if !isCollapsed {
                // "Show earlier departures" button for transfer context
                if !section.isPast && viewModel.hiddenTransferDepartureCount > 0 {
                    showEarlierDeparturesButton
                }

                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    Group {
                        // Walk time / transfer banner at the right position
                        if let banner, banner.insertBeforeIndex == index {
                            walkTimeBannerView(banner)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                        }
                        ArrivalDepartureRowView(row: row, formatters: viewModel.formatters)
                            .contentShape(Rectangle())
                            .onTapGesture { onSelectArrivalDeparture?(row.arrivalDeparture) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                swipeActionsForRow(row)
                            }
                            .contextMenu { contextMenuForRow(row) }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(rowAccessibilityLabel(row))
                            .accessibilityHint(Text("Tap to view trip details"))
                            .accessibilityAddTraits(.isButton)
                    }
                }

                // Banner at end if insertBeforeIndex == rows.count
                if let banner, banner.insertBeforeIndex == section.rows.count {
                    walkTimeBannerView(banner)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }
            }
        } header: {
            if let title = section.title {
                sectionHeader(title: title, sectionID: section.id, isCollapsed: isCollapsed, isPast: section.isPast)
            }
        }
    }

    private func sectionHeader(title: String, sectionID: String, isCollapsed: Bool, isPast: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { viewModel.toggleSection(sectionID) }
            UIAccessibility.post(notification: .layoutChanged, argument: nil)
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                if isPast {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityHint(isPast ? Text(isCollapsed ? "Tap to expand past departures" : "Tap to collapse past departures") : Text(""))
        .accessibilityAddTraits(isPast ? .isButton : [])
    }

    // MARK: - Walk Time Banner

    private func walkTimeBannerView(_ banner: WalkTimeBanner) -> some View {
        Group {
            switch banner.kind {
            case .walkTime(let distance, let timeToWalk):
                WalkTimeBannerView(distance: distance, timeToWalk: timeToWalk, formatters: viewModel.formatters)
            case .transferArrival(let arrivalTime, let routeDisplay):
                TransferArrivalBannerView(arrivalTime: arrivalTime, routeDisplay: routeDisplay, formatters: viewModel.formatters)
            }
        }
    }

    // MARK: - Show Earlier Departures (transfer context)

    private var showEarlierDeparturesButton: some View {
        let count = viewModel.hiddenTransferDepartureCount
        let label = count == 1
            ? OBALoc("stop_controller.transfer_show_earlier_departure_singular", value: "Show 1 earlier departure", comment: "")
            : String(format: OBALoc("stop_controller.transfer_show_earlier_departures_fmt", value: "Show %d earlier departures", comment: ""), count)
        return Button(label) { viewModel.revealHiddenTransferDepartures() }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .accessibilityHint(Text("Shows departures before your transfer arrival time"))
    }

    // MARK: - Swipe Actions

    @ViewBuilder
    private func swipeActionsForRow(_ row: ArrivalDepartureRow) -> some View {
        Button {
            onAddBookmarkForArrivalDeparture?(row.arrivalDeparture)
        } label: {
            Label(Strings.bookmark, systemImage: "bookmark")
        }
        .tint(Color(ThemeColors.shared.brand))

        if row.isAlarmAvailable {
            Button {
                onAddAlarm?(row.arrivalDeparture)
            } label: {
                Label(Strings.alarm, systemImage: "bell")
            }
            .tint(.blue)
        }

        if viewModel.application.currentRegion?.supportsScheduleForRoute ?? true {
            Button {
                onShowScheduleForRoute?(row.arrivalDeparture)
            } label: {
                Label(Strings.schedule, systemImage: "calendar")
            }
            .tint(.teal)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuForRow(_ row: ArrivalDepartureRow) -> some View {
        Button {
            onAddBookmarkForArrivalDeparture?(row.arrivalDeparture)
        } label: {
            Label(Strings.addBookmark, systemImage: "bookmark")
        }

        if row.isAlarmAvailable {
            Button {
                onAddAlarm?(row.arrivalDeparture)
            } label: {
                Label(Strings.addAlarm, systemImage: "bell")
            }
        }

        if viewModel.application.currentRegion?.supportsScheduleForRoute ?? true {
            Button {
                onShowScheduleForRoute?(row.arrivalDeparture)
            } label: {
                Label(Strings.schedule, systemImage: "calendar")
            }
        }

        Button {
            onShareTripStatus?(row.arrivalDeparture)
        } label: {
            Label(OBALoc("stops_controller.share_trip", value: "Share Trip Status", comment: ""), systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - Inline Error (non-fatal, shown above Load More)

    private func inlineErrorRow(_ error: Error) -> some View {
        Label {
            Text(ErrorClassifier.classify(error, regionName: viewModel.application.currentRegionName).localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .listRowSeparator(.hidden)
    }

    // MARK: - Load More

    private var loadMoreButton: some View {
        Button { viewModel.loadMore() } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle")
                    .font(.subheadline)
                Text(OBALoc("stop_controller.load_more_button", value: "Load More", comment: ""))
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .foregroundStyle(.secondary)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
        .accessibilityLabel(Text("Load more departures"))
        .accessibilityHint(Text("Loads departures further into the future"))
    }

    // MARK: - Data Attribution

    private func dataAttributionFooter(stop: Stop) -> some View {
        let agencies = Formatters.formattedAgenciesForRoutes(stop.routes)
        let agencyText = String(format: OBALoc("stop_controller.data_attribution_format", value: "Data provided by %@", comment: ""), agencies)
        let dateRangeText = viewModel.dataDateRangeText
        return VStack(spacing: 1) {
            Text(agencyText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
            if !dateRangeText.isEmpty {
                Text(dateRangeText)
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.vertical, 12)
        .listRowSeparator(.hidden)
    }

    // MARK: - Error View

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.red)
            }
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title3.weight(.semibold))
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }
            Button(OBALoc("common.retry", value: "Retry", comment: "")) {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Accessibility helpers

    private func rowAccessibilityLabel(_ row: ArrivalDepartureRow) -> Text {
        let minutes = row.arrivalDepartureMinutes
        let timeDesc: String
        if minutes < 0 { timeDesc = "\(abs(minutes)) minutes ago" }
        else if minutes == 0 { timeDesc = "now" }
        else { timeDesc = "in \(minutes) minutes" }
        return Text("\(row.routeAndHeadsign), \(timeDesc)")
    }
}

// MARK: - StopDetailHeaderView

private struct StopDetailHeaderView: View {
    let stop: Stop
    @State private var snapshotImage: UIImage? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map snapshot — fills the full header
            Group {
                if let image = snapshotImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(ThemeColors.shared.brand).opacity(0.9)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160)
            .clipped()

            // Bottom-to-top gradient — protects text, hides Apple Maps watermark
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.0), location: 0.0),
                    .init(color: .black.opacity(0.55), location: 0.45),
                    .init(color: .black.opacity(0.82), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity, minHeight: 160)

            // Text content — pinned to bottom with clear hierarchy
            VStack(alignment: .leading, spacing: 4) {
                // Stop name — title case via capitalized
                Text(stop.name.localizedCapitalized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Stop code + direction + routes on one line
                HStack(spacing: 0) {
                    Text(Formatters.formattedCodeAndDirection(stop: stop))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))

                    if let routes = Formatters.formattedRoutes(stop.routes), !routes.isEmpty {
                        Text("  ·  \(routes)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .padding(.top, 40) // ensures gradient has room above text
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(stop.name), \(Formatters.formattedCodeAndDirection(stop: stop))"))
        .accessibilityAddTraits(.isHeader)
        .task(id: stop.id) {
            await loadSnapshot()
        }
    }

    @MainActor
    private func loadSnapshot() async {
        let width = UIScreen.main.bounds.width
        let size = CGSize(width: width, height: 160)
        let factory = StopIconFactory(
            iconSize: ThemeMetrics.defaultMapAnnotationSize,
            themeColors: ThemeColors.shared
        )
        let snapshotter = MapSnapshotter(size: size, stopIconFactory: factory)
        let traits = UITraitCollection.current
        await withCheckedContinuation { continuation in
            snapshotter.snapshot(stop: stop, traitCollection: traits) { image in
                Task { @MainActor in
                    self.snapshotImage = image
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - ArrivalDepartureRowView

struct ArrivalDepartureRowView: View {
    let row: ArrivalDepartureRow
    let formatters: Formatters

    var body: some View {
        HStack(spacing: 12) {
            // Left accent bar — schedule status color
            RoundedRectangle(cornerRadius: 2)
                .fill(row.temporalState == .past ? Color.secondary.opacity(0.3) : scheduleStatusColor)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.routeAndHeadsign)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(row.temporalState == .past ? .secondary : .primary)

                Text(fullExplanation)
                    .font(.caption)
                    .foregroundStyle(row.temporalState == .past ? Color(.tertiaryLabel) : scheduleStatusColor)
                    .lineLimit(1)

                if let occupancy = row.occupancyStatus ?? row.historicalOccupancyStatus,
                   occupancy != .unknown {
                    OccupancyStatusBadge(status: occupancy, isRealtime: row.occupancyStatus != nil)
                }
            }

            Spacer(minLength: 8)

            // Minutes badge
            Text(minutesText)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(row.temporalState == .past ? .secondary : scheduleStatusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    (row.temporalState == .past ? Color.secondary : scheduleStatusColor)
                        .opacity(0.1)
                )
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var minutesText: String {
        formatters.shortFormattedTime(untilMinutes: row.arrivalDepartureMinutes, temporalState: row.temporalState)
    }

    private var fullExplanation: String {
        formatters.fullAttributedArrivalDepartureExplanation(
            arrivalDepartureDate: row.arrivalDepartureDate,
            scheduleStatus: row.scheduleStatus,
            temporalState: row.temporalState,
            arrivalDepartureStatus: row.arrivalDepartureStatus,
            scheduleDeviationInMinutes: row.deviationFromScheduleInMinutes
        ).string
    }

    private var scheduleStatusColor: Color {
        Color(formatters.colorForScheduleStatus(row.scheduleStatus))
    }
}

// MARK: - OccupancyStatusBadge

private struct OccupancyStatusBadge: View {
    let status: ArrivalDeparture.OccupancyStatus
    let isRealtime: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: isRealtime ? "person.3.fill" : "person.3")
                .font(.caption2)
            Text(label)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .accessibilityLabel(Text("Occupancy: \(label)\(isRealtime ? "" : " (historical)")"))
    }

    private var label: String {
        switch status {
        case .empty:                  return OBALoc("occupancy.empty", value: "Empty", comment: "")
        case .manySeatsAvailable:     return OBALoc("occupancy.many_seats", value: "Many seats", comment: "")
        case .fewSeatsAvailable:      return OBALoc("occupancy.few_seats", value: "Few seats", comment: "")
        case .standingRoomOnly:       return OBALoc("occupancy.standing_room", value: "Standing room", comment: "")
        case .crushedStandingRoomOnly:return OBALoc("occupancy.crushed", value: "Very crowded", comment: "")
        case .full:                   return OBALoc("occupancy.full", value: "Full", comment: "")
        case .notAcceptingPassengers: return OBALoc("occupancy.not_accepting", value: "Not accepting", comment: "")
        case .notBoardable:           return OBALoc("occupancy.not_boardable", value: "Not boardable", comment: "")
        case .noDataAvailable, .unknown: return ""
        }
    }

    private var color: Color {
        switch status {
        case .empty, .manySeatsAvailable:                  return .green
        case .fewSeatsAvailable:                           return .yellow
        case .standingRoomOnly, .crushedStandingRoomOnly:  return .orange
        case .full, .notAcceptingPassengers, .notBoardable: return .red
        case .noDataAvailable, .unknown:                   return .secondary
        }
    }
}

// MARK: - Walk Time Banner Views

private struct WalkTimeBannerView: View {
    let distance: CLLocationDistance
    let timeToWalk: TimeInterval
    let formatters: Formatters

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(ThemeColors.shared.brand))
            Text(bannerText)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(ThemeColors.shared.brand).opacity(0.08))
        .accessibilityLabel(Text(OBALoc("walk_time_view.accessibility_label", value: "Time to walk to stop", comment: "")))
        .accessibilityValue(Text(bannerText))
    }

    private var bannerText: String {
        let distanceString = formatters.distanceFormatter.string(fromDistance: distance)
        let arrivalTime = formatters.timeFormatter.string(from: Date().addingTimeInterval(timeToWalk))
        if let timeString = formatters.positionalTimeFormatter.string(from: timeToWalk) {
            return String(format: OBALoc("walk_time_view.distance_time_fmt", value: "%@, %@: arriving at %@", comment: ""), distanceString, timeString, arrivalTime)
        }
        return distanceString
    }
}

private struct TransferArrivalBannerView: View {
    let arrivalTime: Date
    let routeDisplay: String
    let formatters: Formatters

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.swap")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(ThemeColors.shared.brand))
            Text(formatters.transferArrivalBannerText(arrivalTime: arrivalTime, routeDisplay: routeDisplay))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(ThemeColors.shared.brand).opacity(0.08))
        .accessibilityLabel(Text(OBALoc("walk_time_view.transfer_accessibility_label", value: "Transfer arrival time", comment: "")))
        .accessibilityValue(Text(formatters.transferArrivalBannerText(arrivalTime: arrivalTime, routeDisplay: routeDisplay)))
    }
}
