//
//  ArrivalTimelineEntry.swift
//  OBAWatchComplication
//
//  Created by Prince Yadav on 31/12/25.
//

import WidgetKit
import Foundation

/// A single snapshot of data for the watch face complication.
struct ArrivalTimelineEntry: TimelineEntry {
    /// Struct representing a secondary upcoming arrival.
    struct NextArrival: Hashable {
        let routeShortName: String?
        let minutesOnlyText: String
        let isPredicted: Bool
    }

    /// The date this entry should be displayed from.
    let date: Date

    /// The stop name shown as the complication title (e.g. "5th Ave & Pine St").
    let stopName: String

    /// The route short name (e.g. "10", "Link Light Rail").
    let routeShortName: String?

    /// Trip headsign destination (e.g. "Downtown / Capitol Hill").
    let headsign: String?

    /// The predicted/scheduled arrival time.
    let arrivalDate: Date?

    /// Whether this arrival is real-time predicted (green) or only scheduled (grey).
    let isPredicted: Bool

    /// Formatted schedule status label (e.g. "On Time", "+3m Late", "Early").
    let scheduleStatusText: String?

    /// Next upcoming arrivals for secondary chip previews.
    let nextArrivals: [NextArrival]

    init(
        date: Date,
        stopName: String,
        routeShortName: String?,
        headsign: String? = nil,
        arrivalDate: Date?,
        isPredicted: Bool,
        scheduleStatusText: String? = nil,
        nextArrivals: [NextArrival] = []
    ) {
        self.date = date
        self.stopName = stopName
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.arrivalDate = arrivalDate
        self.isPredicted = isPredicted
        self.scheduleStatusText = scheduleStatusText
        self.nextArrivals = nextArrivals
    }

    // MARK: - Derived Display Helpers

    /// Human-readable minutes until arrival, e.g. "4 min", "Now", "Scheduled".
    var minutesUntilArrival: String {
        let text = minutesOnlyText
        if Int(text) != nil {
            return String(format: NSLocalizedString("complication.minutes_fmt", value: "%@ min", comment: "Minutes until arrival format"), text)
        }
        return text
    }

    /// Just the number (e.g. "4") or a localized string ("Now", "Scheduled").
    var minutesOnlyText: String {
        guard let arrival = arrivalDate else {
            return NSLocalizedString("complication.scheduled", value: "Scheduled", comment: "Arrival is only scheduled, no real-time data")
        }
        let minutes = Int(arrival.timeIntervalSinceNow / 60)
        if minutes <= 0 {
            return NSLocalizedString("complication.now", value: "Now", comment: "Bus is arriving now")
        }
        return "\(minutes)"
    }

    /// Numerical value in minutes for native SwiftUI Gauge representations (clamped to 0...30).
    var minutesValue: Double {
        guard let arrival = arrivalDate else { return 0 }
        let mins = arrival.timeIntervalSinceNow / 60.0
        return max(0, min(30, mins))
    }

    /// Short display suitable for the corner complication, e.g. "10 • 4m".
    var cornerLabel: String {
        guard let arrival = arrivalDate else {
            return routeShortName ?? stopName
        }
        let minutes = max(0, Int(arrival.timeIntervalSinceNow / 60))
        let route = routeShortName ?? "—"
        return "\(route) • \(minutes)m"
    }

    /// Inline text suitable for accessoryInline complications, e.g. "🚌 10 to Downtown • 4m".
    var inlineText: String {
        let route = routeShortName ?? "Bus"
        let minText = minutesUntilArrival
        if let head = headsign, !head.isEmpty {
            return "\(route) to \(head) • \(minText)"
        }
        return "\(route) • \(minText)"
    }

    /// A placeholder entry used when no data is available yet.
    static var placeholder: ArrivalTimelineEntry {
        ArrivalTimelineEntry(
            date: Date(),
            stopName: NSLocalizedString("complication.placeholder_stop", value: "3rd Ave & Pine St", comment: "Placeholder stop name"),
            routeShortName: "10",
            headsign: "Downtown",
            arrivalDate: Date().addingTimeInterval(4 * 60),
            isPredicted: true,
            scheduleStatusText: "On Time",
            nextArrivals: [
                NextArrival(routeShortName: "10", minutesOnlyText: "12", isPredicted: true),
                NextArrival(routeShortName: "11", minutesOnlyText: "18", isPredicted: false)
            ]
        )
    }
}
