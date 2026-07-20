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
            // Header with Bus icon, Route, and Real-time indicator
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "bus.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(entry.isPredicted ? Color.green : Color.primary)
                
                if let route = entry.routeShortName {
                    Text(route)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer(minLength: 0)
                
                if entry.isPredicted {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.green)
                        .widgetAccentable()
                }
            }
            
            // Stop Name
            Text(entry.stopName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            
            // Arrival Time
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(entry.minutesOnlyText)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
                    .minimumScaleFactor(0.8)
                
                if let min = minutesInt, min > 0 {
                    Text(NSLocalizedString("complication.min_suffix", value: "min", comment: "Minutes suffix for complication"))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var minutesInt: Int? {
        guard let arrival = entry.arrivalDate else { return nil }
        return max(0, Int(arrival.timeIntervalSinceNow / 60))
    }
}

#Preview(as: .accessoryRectangular) {
    OBAWatchComplicationWidget()
} timeline: {
    ArrivalTimelineEntry.placeholder
}
