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
        VStack(alignment: .leading, spacing: 2) {
            // Stop name
            Text(entry.stopName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Route + arrival row
            HStack(spacing: 4) {
                Circle()
                    .fill(entry.isPredicted ? Color.green : Color.gray)
                    .frame(width: 6, height: 6)

                if let route = entry.routeShortName {
                    Text("Route \(route)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(entry.minutesUntilArrival)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.isPredicted ? .green : .primary)
            }
        }
        .padding(.horizontal, 4)
    }
}

#Preview(as: .accessoryRectangular) {
    OBAWatchComplicationWidget()
} timeline: {
    ArrivalTimelineEntry.placeholder
}
