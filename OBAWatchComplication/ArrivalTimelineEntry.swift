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
    /// The date this entry should be displayed from.
    let date: Date

    /// The stop name shown as the complication title (e.g. "5th Ave & Pine St").
    let stopName: String

    /// The route short name (e.g. "10", "Link Light Rail").
    let routeShortName: String?

    /// The predicted/scheduled arrival time.
    let arrivalDate: Date?

    /// Whether this arrival is real-time predicted (green) or only scheduled (grey).
    let isPredicted: Bool

    // MARK: - Derived Display Helpers

    /// Human-readable minutes until arrival, e.g. "4 min", "Now", "Scheduled".
    var minutesUntilArrival: String {
        guard let arrival = arrivalDate else {
            return NSLocalizedString("complication.scheduled", value: "Scheduled", comment: "Arrival is only scheduled, no real-time data")
        }
        let minutes = Int(arrival.timeIntervalSinceNow / 60)
        if minutes <= 0 {
            return NSLocalizedString("complication.now", value: "Now", comment: "Bus is arriving now")
        }
        return String(format: NSLocalizedString("complication.minutes_fmt", value: "%d min", comment: "Minutes until arrival format"), minutes)
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

    /// A placeholder entry used when no data is available yet.
    static var placeholder: ArrivalTimelineEntry {
        ArrivalTimelineEntry(
            date: Date(),
            stopName: NSLocalizedString("complication.placeholder_stop", value: "My Stop", comment: "Placeholder stop name"),
            routeShortName: "10",
            arrivalDate: Date().addingTimeInterval(4 * 60),
            isPredicted: true
        )
    }
}
