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
        ZStack {
            // Background ring
            Circle()
                .fill(tintColor.opacity(0.15))
                .overlay(
                    Circle()
                        .strokeBorder(tintColor, lineWidth: 2)
                )

            VStack(spacing: 0) {
                Text(entry.minutesOnlyText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(tintColor)
                    .minimumScaleFactor(0.6)

                if let route = entry.routeShortName {
                    Text(route)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Helpers

    private var tintColor: Color {
        entry.isPredicted ? .green : .gray
    }
}

#Preview(as: .accessoryCircular) {
    OBAWatchComplicationWidget()
} timeline: {
    ArrivalTimelineEntry.placeholder
}
