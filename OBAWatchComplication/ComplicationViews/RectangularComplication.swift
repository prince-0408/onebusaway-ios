//
//  RectangularComplication.swift
//  OBAWatchComplication
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import WidgetKit

/// Rectangular watch face complication showing stop name, route, and arrival time.
///
/// Example:
///   "5th & Pike"
///   Route 10 ● 4 min  [green dot = real-time]
struct RectangularComplication: View {
    let entry: ArrivalTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Header Row: Route Pill + Destination Headsign (Left) | Live/Scheduled Pill (Right)
            HStack(alignment: .center, spacing: 4) {
                if let route = entry.routeShortName {
                    Text(route)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(entry.isPredicted ? Color.green : Color.cyan, in: Capsule())
                }

                Text(entry.headsign ?? entry.stopName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                if entry.isPredicted {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 5, height: 5)
                        Text("LIVE")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(Color.green)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.green.opacity(0.15), in: Capsule())
                } else {
                    Text("SCHEDULED")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(Color.cyan)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Color.cyan.opacity(0.18), in: Capsule())
                }
            }

            // Primary Row: ETA Countdown (Left) | Schedule Adherence & Clock Time (Right)
            HStack(alignment: .center, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(entry.minutesOnlyText)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(entry.isPredicted ? Color.primary : Color.cyan)
                        .widgetAccentable()
                        .minimumScaleFactor(0.7)

                    if let min = minutesInt, min > 0 {
                        Text(NSLocalizedString("complication.min_suffix", value: "min", comment: "Minutes suffix for complication"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                if entry.isPredicted {
                    if let status = entry.scheduleStatusText {
                        HStack(spacing: 3) {
                            Text(status)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.green)
                            if let timeString = formattedTime {
                                Text("•")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                                Text(timeString)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    }
                } else if let timeString = formattedTime {
                    HStack(spacing: 3) {
                        Text(timeString)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.cyan)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                }
            }

            // Footer Row: Next Departures (Left) | Stop Location (Right)
            HStack(alignment: .center, spacing: 4) {
                if let next = entry.nextArrivals.first {
                    HStack(spacing: 3) {
                        Text("Next:")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                        Text("\(next.minutesOnlyText)m")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        if let second = entry.nextArrivals.dropFirst().first {
                            Text("•")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                            Text("\(second.minutesOnlyText)m")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.tertiary)
                        }
                    }
                } else {
                    Text("No later trips")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)

                HStack(spacing: 2) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    Text(entry.stopName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
        .padding(.vertical, 1)
    }

    private var minutesInt: Int? {
        guard let arrival = entry.arrivalDate else { return nil }
        return max(0, Int(arrival.timeIntervalSinceNow / 60))
    }

    private var formattedTime: String? {
        guard let arrival = entry.arrivalDate else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrival)
    }
}

#Preview(as: .accessoryRectangular) {
    OBAWatchComplicationWidget()
} timeline: {
    // 1. Real-time arrival with destination headsign & next departure chip
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date().addingTimeInterval(4 * 60),
        isPredicted: true,
        scheduleStatusText: "On Time",
        nextArrivals: [
            ArrivalTimelineEntry.NextArrival(routeShortName: "10", minutesOnlyText: "14", isPredicted: true),
            ArrivalTimelineEntry.NextArrival(routeShortName: "11", minutesOnlyText: "22", isPredicted: false)
        ]
    )
    // 2. Arriving NOW
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date(),
        isPredicted: true,
        scheduleStatusText: "Arriving",
        nextArrivals: [
            ArrivalTimelineEntry.NextArrival(routeShortName: "10", minutesOnlyText: "10", isPredicted: true)
        ]
    )
    // 3. Scheduled trip
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "C Line",
        headsign: "West Seattle",
        arrivalDate: Date().addingTimeInterval(18 * 60),
        isPredicted: false,
        scheduleStatusText: "Scheduled",
        nextArrivals: []
    )
}
