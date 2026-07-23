//
//  CircularComplication.swift
//  OBAWatchComplication
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import WidgetKit

/// Circular watch face complication showing the countdown in minutes.
///
/// Example: a green circle with "4" centred, route badge below ("10").
struct CircularComplication: View {
    let entry: ArrivalTimelineEntry

    var body: some View {
        // When vehicle is arriving NOW (<=0.5 mins), show full ring (1.0 progress)
        let progress: Double = {
            guard let arrival = entry.arrivalDate else { return 0.04 }
            let mins = arrival.timeIntervalSinceNow / 60.0
            if mins <= 0.5 { return 1.0 }
            return min(1.0, max(0.04, mins / 30.0))
        }()

        ZStack {
            // Subtle 12 o'clock top tick mark marking scale start/end (0 / 30m)
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 1.5, height: 4)
                Spacer()
            }

            // Moving green progress arc with rounded caps
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    entry.isPredicted ? Color.green : Color.blue,
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(2)

            // Centered layout: Route badge capsule + ETA Countdown
            VStack(spacing: 0) {
                if let route = entry.routeShortName {
                    Text(route)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(entry.isPredicted ? Color.green : Color.primary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            (entry.isPredicted ? Color.green : Color.white).opacity(0.2),
                            in: Capsule()
                        )
                        .lineLimit(1)
                }

                Text(entry.minutesOnlyText)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .widgetAccentable()
            }
        }
    }
}

#Preview(as: .accessoryCircular) {
    OBAWatchComplicationWidget()
} timeline: {
    // 28 min ETA (Near start of 30m scale -> 93% full green arc)
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date().addingTimeInterval(28 * 60),
        isPredicted: true,
        scheduleStatusText: "On Time"
    )
    // 15 min ETA (Mid-way -> 50% half green arc)
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date().addingTimeInterval(15 * 60),
        isPredicted: true,
        scheduleStatusText: "On Time"
    )
    // 3 min ETA (Close -> 10% green arc)
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date().addingTimeInterval(3 * 60),
        isPredicted: true,
        scheduleStatusText: "On Time"
    )
    // Arriving NOW (0 min ETA -> Full green ring)
    ArrivalTimelineEntry(
        date: Date(),
        stopName: "3rd Ave & Pine",
        routeShortName: "10",
        headsign: "Downtown",
        arrivalDate: Date(),
        isPredicted: true,
        scheduleStatusText: "Arriving"
    )
}
