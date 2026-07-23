//
//  CornerComplication.swift
//  OBAWatchComplication
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import WidgetKit

/// Corner watch face complication — the most terse layout.
/// Renders a transit icon gauge with a label like "10 • 4m".
struct CornerComplication: View {
    let entry: ArrivalTimelineEntry

    var body: some View {
        ZStack {
            Circle()
                .fill(entry.isPredicted ? Color(red: 0.04, green: 0.28, blue: 0.12) : Color.blue.opacity(0.3))
                .overlay(
                    Circle()
                        .strokeBorder(entry.isPredicted ? Color.green : Color.blue, lineWidth: 1.5)
                )

            if let route = entry.routeShortName, route.count <= 3 {
                Text(route)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(entry.isPredicted ? Color.green : Color.white)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                    .padding(1)
            } else {
                Image(systemName: "bus.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(entry.isPredicted ? Color.green : Color.white)
            }
        }
        .widgetLabel {
            Text(entry.cornerLabel)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.heavy)
                .monospacedDigit()
                .textCase(.none)
                .foregroundStyle(entry.isPredicted ? Color.green : Color.primary)
        }
    }
}

/// Inline watch face complication view suitable for Apple Watch faces and lock screen inline slots.
/// Displays single-line formatted transit status, e.g. "🚌 10 to Downtown • 4m"
struct InlineComplication: View {
    let entry: ArrivalTimelineEntry

    var body: some View {
        ViewThatFits {
            HStack(spacing: 4) {
                Image(systemName: "bus.fill")
                Text(entry.inlineText)
            }
            Text(entry.cornerLabel)
        }
        .font(.system(.footnote, design: .rounded))
        .fontWeight(.bold)
    }
}

#Preview(as: .accessoryCorner) {
    OBAWatchComplicationWidget()
} timeline: {
    // 1. Real-time predicted arrival (3 min)
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date().addingTimeInterval(3 * 60),
        isPredicted: true,
        scheduleStatusText: "On Time"
    )
    // 2. Arriving NOW (0 min)
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date(),
        isPredicted: true,
        scheduleStatusText: "Arriving"
    )
    // 3. Scheduled arrival (15 min)
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "C Line",
        headsign: "West Seattle",
        arrivalDate: Date().addingTimeInterval(15 * 60),
        isPredicted: false,
        scheduleStatusText: "Scheduled"
    )
}

#Preview(as: .accessoryInline) {
    OBAWatchComplicationWidget()
} timeline: {
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date().addingTimeInterval(3 * 60),
        isPredicted: true,
        scheduleStatusText: "On Time"
    )
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "C Line",
        headsign: "West Seattle",
        arrivalDate: Date().addingTimeInterval(12 * 60),
        isPredicted: false,
        scheduleStatusText: "Scheduled"
    )
}
