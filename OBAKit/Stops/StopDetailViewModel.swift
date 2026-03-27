//
//  StopDetailViewModel.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import OBAKitCore
import Combine
import UIKit
import CoreLocation

// MARK: - Row Models

struct ArrivalDepartureRow: Identifiable, Equatable {
    let id: String
    let routeAndHeadsign: String
    let scheduledDate: Date
    let arrivalDepartureDate: Date
    let arrivalDepartureMinutes: Int
    let scheduleStatus: ScheduleStatus
    let temporalState: TemporalState
    let arrivalDepartureStatus: ArrivalDepartureStatus
    let deviationFromScheduleInMinutes: Int
    let isAlarmAvailable: Bool
    let occupancyStatus: ArrivalDeparture.OccupancyStatus?
    let historicalOccupancyStatus: ArrivalDeparture.OccupancyStatus?
    let arrivalDeparture: ArrivalDeparture

    init(arrivalDeparture: ArrivalDeparture, isAlarmAvailable: Bool) {
        self.id = arrivalDeparture.id
        self.routeAndHeadsign = arrivalDeparture.routeAndHeadsign
        self.scheduledDate = arrivalDeparture.scheduledDate
        self.arrivalDepartureDate = arrivalDeparture.arrivalDepartureDate
        self.arrivalDepartureMinutes = arrivalDeparture.arrivalDepartureMinutes
        self.scheduleStatus = arrivalDeparture.scheduleStatus
        self.temporalState = arrivalDeparture.temporalState
        self.arrivalDepartureStatus = arrivalDeparture.arrivalDepartureStatus
        self.deviationFromScheduleInMinutes = arrivalDeparture.deviationFromScheduleInMinutes
        self.isAlarmAvailable = isAlarmAvailable
        self.occupancyStatus = arrivalDeparture.occupancyStatus
        self.historicalOccupancyStatus = arrivalDeparture.historicalOccupancyStatus
        self.arrivalDeparture = arrivalDeparture
    }

    static func == (lhs: ArrivalDepartureRow, rhs: ArrivalDepartureRow) -> Bool {
        lhs.id == rhs.id &&
        lhs.arrivalDepartureMinutes == rhs.arrivalDepartureMinutes &&
        lhs.scheduleStatus == rhs.scheduleStatus &&
        lhs.temporalState == rhs.temporalState
    }
}

struct ArrivalDepartureSection: Identifiable {
    let id: String
    let title: String?
    let isPast: Bool
    var rows: [ArrivalDepartureRow]
}

/// Walk-time or transfer banner inserted between departure rows.
struct WalkTimeBanner: Equatable {
    enum Kind: Equatable {
        case walkTime(distance: CLLocationDistance, timeToWalk: TimeInterval)
        case transferArrival(arrivalTime: Date, routeDisplay: String)
    }
    let kind: Kind
    /// Insert this banner before the row at this index.
    let insertBeforeIndex: Int
}

// MARK: - StopDetailViewModel

@MainActor
final class StopDetailViewModel: ObservableObject {

    // MARK: Published state
    @Published var stop: Stop?
    @Published var sections: [ArrivalDepartureSection] = []
    @Published var serviceAlerts: [ServiceAlert] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var inlineError: Error?   // shown above Load More, not full-screen
    @Published var lastUpdated: Date?
    @Published var minutesAfter: UInt = 35
    @Published var isFiltered: Bool = true
    @Published var sortType: StopSort = .time
    @Published var collapsedSectionIDs: Set<String> = []
    @Published var isBrokenBookmark = false
    @Published var showAllTransferDepartures = false
    @Published var hiddenTransferDepartureCount = 0
    @Published var statusText: String = ""
    @Published var isPreviewMode = false

    // MARK: Internal
    let application: Application
    let stopID: StopID
    var bookmarkContext: Bookmark?
    var transferContext: TransferContext?

    // MARK: Private
    private var stopArrivals: StopArrivals?
    private var stopPreferences: StopPreferences
    private var reloadTimer: Timer?
    private static let timerInterval: TimeInterval = 30.0
    private let minutesBefore: UInt = 5
    private var firstLoad = true
    private lazy var dataLoadFeedbackGenerator = DataLoadFeedbackGenerator(application: application)

    // MARK: Init
    init(application: Application, stopID: StopID, stop: Stop? = nil) {
        self.application = application
        self.stopID = stopID
        self.stop = stop
        self.stopPreferences = application.stopPreferencesDataStore.preferences(
            stopID: stopID,
            region: application.currentRegion!
        )
        self.sortType = stopPreferences.sortType
        if let stop = stop { recordRecentStop(stop) }
        startTimer()
    }

    deinit { reloadTimer?.invalidate() }

    // MARK: - Public API

    func loadData() async {
        guard let apiService = application.apiService else { return }
        isLoading = sections.isEmpty
        error = nil
        statusText = Strings.updating

        do {
            let response = try await apiService.getArrivalsAndDeparturesForStop(
                id: stopID, minutesBefore: minutesBefore, minutesAfter: minutesAfter
            ).entry

            stopArrivals = response
            stop = response.stop
            lastUpdated = Date()
            isLoading = false
            isBrokenBookmark = false
            inlineError = nil

            if let stop = stop { recordRecentStop(stop) }

            let isFirst = firstLoad
            if firstLoad { firstLoad = false } else { dataLoadFeedbackGenerator.dataLoad(.success) }

            updateStatusText()
            if response.arrivalsAndDepartures.isEmpty { extendLoadMoreWindow() }
            rebuildSections()

            // Collapse past sections on first load after sections are built
            if isFirst && pastDeparturesCollapsed {
                collapsedSectionIDs.insert("past_all")
                for section in sections where section.isPast {
                    collapsedSectionIDs.insert(section.id)
                }
            }

            // Fetch surveys in background after main data loads
            Task { [weak self] in
                guard let self else { return }
                await application.surveyService.fetchSurveys()
                rebuildSections()
            }
        } catch APIError.requestNotFound {
            isBrokenBookmark = bookmarkContext != nil
            dataLoadFeedbackGenerator.dataLoad(.failed)
            isLoading = false
        } catch {
            self.inlineError = error  // show inline, not full-screen, so list remains visible
            self.error = sections.isEmpty ? error : nil  // full-screen only when no data yet
            dataLoadFeedbackGenerator.dataLoad(.failed)
            isLoading = false
        }
    }

    func loadMore() {
        minutesAfter += 30
        Task { await loadData() }
    }

    func toggleSection(_ id: String) {
        if collapsedSectionIDs.contains(id) { collapsedSectionIDs.remove(id) }
        else { collapsedSectionIDs.insert(id) }
        // Persist past-departures collapsed state
        let hasPastCollapsed = collapsedSectionIDs.contains(where: { $0.hasPrefix("past_") })
        pastDeparturesCollapsed = hasPastCollapsed
    }

    func isSectionCollapsed(_ id: String) -> Bool { collapsedSectionIDs.contains(id) }

    func setSortType(_ type: StopSort) {
        sortType = type
        stopPreferences.sortType = type
        if let stop = stop, let region = application.currentRegion {
            application.stopPreferencesDataStore.set(stopPreferences: stopPreferences, stop: stop, region: region)
        }
        rebuildSections()
    }

    func setFiltered(_ filtered: Bool) {
        isFiltered = filtered
        rebuildSections()
    }

    func revealHiddenTransferDepartures() {
        showAllTransferDepartures = true
        rebuildSections()
    }

    var formatters: Formatters { application.formatters }
    var shouldShowDonations: Bool { application.donationsManager.shouldRequestDonations }

    var dataDateRangeText: String {
        let before = Date().addingTimeInterval(Double(minutesBefore) * -60.0)
        let after = Date().addingTimeInterval(Double(minutesAfter) * 60.0)
        return application.formatters.formattedDateRange(from: before, to: after)
    }

    /// Persisted: whether service alerts section is expanded (mirrors original UserDefaults key).
    var stopViewShowsServiceAlerts: Bool {
        get { application.userDefaults.bool(forKey: "stopViewShowsServiceAlerts") }
        set { application.userDefaults.set(newValue, forKey: "stopViewShowsServiceAlerts") }
    }

    /// Persisted: whether past departures are collapsed (mirrors original UserDefaults key).
    var pastDeparturesCollapsed: Bool {
        get { application.userDefaults.bool(forKey: "StopViewController.pastDeparturesCollapsed") }
        set { application.userDefaults.set(newValue, forKey: "StopViewController.pastDeparturesCollapsed") }
    }

    var currentSurvey: Survey? {
        guard let stop = stop else { return nil }
        let routeIDs = stop.routes.map { $0.id }
        return application.surveyService.findSurveyForStop(stopID: stopID, routeIDs: routeIDs)
    }

    /// Walk-time or transfer banner for the upcoming (sort-by-time) section.
    func walkTimeBanner(rows: [ArrivalDepartureRow]) -> WalkTimeBanner? {
        if let tc = transferContext {
            let idx = rows.firstIndex { $0.arrivalDepartureDate >= tc.arrivalTime } ?? 0
            return WalkTimeBanner(
                kind: .transferArrival(arrivalTime: tc.arrivalTime, routeDisplay: tc.fromRouteDisplay),
                insertBeforeIndex: idx
            )
        }
        guard let currentLocation = application.locationService.currentLocation,
              let stopLocation = stop?.location,
              let walkingTime = WalkingDirections.travelTime(from: currentLocation, to: stopLocation)
        else { return nil }

        let distance = currentLocation.distance(from: stopLocation)
        guard distance > 40 else { return nil }

        let idx = rows.firstIndex { $0.scheduledDate.timeIntervalSinceNow >= walkingTime } ?? rows.count
        return WalkTimeBanner(kind: .walkTime(distance: distance, timeToWalk: walkingTime), insertBeforeIndex: idx)
    }

    // MARK: - Private helpers

    private func recordRecentStop(_ stop: Stop) {
        if let region = application.currentRegion {
            application.userDataStore.addRecentStop(stop, region: region)
        }
    }

    private func startTimer() {
        reloadTimer = Timer.scheduledTimer(withTimeInterval: Self.timerInterval / 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let last = self.lastUpdated, abs(last.timeIntervalSinceNow) > Self.timerInterval else { return }
                await self.loadData()
            }
        }
    }

    private func updateStatusText() {
        guard let lastUpdated else { statusText = ""; return }
        statusText = String(format: Strings.updatedAtFormat, application.formatters.timeAgoInWords(date: lastUpdated))
    }

    /// Auto-extends the time window when no arrivals are returned (e.g. late night).
    private func extendLoadMoreWindow() {
        guard minutesAfter < 720 else { return }
        if minutesAfter < 60 { minutesAfter = 60 }
        else if minutesAfter < 240 { minutesAfter += 60 }
        else { minutesAfter += 120 }
    }

    func rebuildSections() {
        guard let stopArrivals else { sections = []; serviceAlerts = []; return }
        serviceAlerts = stopArrivals.serviceAlerts
        var built: [ArrivalDepartureSection] = []

        if sortType == .time {
            let all = isFiltered
                ? stopArrivals.arrivalsAndDepartures.filter(preferences: stopPreferences).filteringTerminalDuplicates()
                : stopArrivals.arrivalsAndDepartures.filteringTerminalDuplicates()

            let past = all.filter { $0.arrivalDepartureMinutes < 0 }
            var upcoming = all.filter { $0.arrivalDepartureMinutes >= 0 }

            // Transfer context: hide departures before arrival time unless user opted in
            if let tc = transferContext, !showAllTransferDepartures {
                let (visible, hidden) = partitionTransfer(upcoming, arrivalTime: tc.arrivalTime)
                upcoming = visible
                hiddenTransferDepartureCount = hidden.count
            } else {
                hiddenTransferDepartureCount = 0
            }

            if !past.isEmpty {
                built.append(ArrivalDepartureSection(
                    id: "past_all",
                    title: OBALoc("stop_controller.past_departures_header", value: "Past Departures", comment: ""),
                    isPast: true,
                    rows: past.map { ArrivalDepartureRow(arrivalDeparture: $0, isAlarmAvailable: canCreateAlarmForDep($0)) }
                ))
            }

            built.append(ArrivalDepartureSection(
                id: "upcoming_all",
                title: OBALoc("stop_controller.arrival_departure_header", value: "Arrivals and Departures", comment: ""),
                isPast: false,
                rows: upcoming.map { ArrivalDepartureRow(arrivalDeparture: $0, isAlarmAvailable: canCreateAlarmForDep($0)) }
            ))
        } else {
            let groups = stopArrivals.arrivalsAndDepartures
                .group(preferences: stopPreferences, filter: isFiltered)
                .localizedStandardCompare()

            for group in groups {
                let filtered = group.arrivalDepartures.filteringTerminalDuplicates()
                let past = filtered.filter { $0.arrivalDepartureMinutes < 0 }
                let upcoming = filtered.filter { $0.arrivalDepartureMinutes >= 0 }
                let routeName = group.route.longName ?? group.route.shortName

                if !past.isEmpty {
                    built.append(ArrivalDepartureSection(
                        id: "past_\(group.route.id)",
                        title: String(format: OBALoc("stop_controller.past_departures_route_header", value: "Past Departures - %@", comment: ""), routeName),
                        isPast: true,
                        rows: past.map { ArrivalDepartureRow(arrivalDeparture: $0, isAlarmAvailable: canCreateAlarmForDep($0)) }
                    ))
                }

                built.append(ArrivalDepartureSection(
                    id: "route_\(group.route.id)",
                    title: routeName,
                    isPast: false,
                    rows: upcoming.map { ArrivalDepartureRow(arrivalDeparture: $0, isAlarmAvailable: canCreateAlarmForDep($0)) }
                ))
            }
        }

        sections = built
    }

    private func partitionTransfer(_ rows: [ArrivalDeparture], arrivalTime: Date) -> (visible: [ArrivalDeparture], hidden: [ArrivalDeparture]) {
        var visible: [ArrivalDeparture] = []
        var hidden: [ArrivalDeparture] = []
        for row in rows {
            if row.arrivalDepartureDate < arrivalTime { hidden.append(row) } else { visible.append(row) }
        }
        return (visible, hidden)
    }

    private func canCreateAlarmForDep(_ dep: ArrivalDeparture) -> Bool {
        application.features.obaco == .running &&
        application.features.push == .running &&
        dep.arrivalDepartureMinutes > 1
    }
}
