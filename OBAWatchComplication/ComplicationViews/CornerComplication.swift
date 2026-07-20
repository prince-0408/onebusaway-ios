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
        // accessoryCorner renders a gauge + label curve; we use text only.
        ZStack {
            Image(systemName: "bus.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(entry.isPredicted ? .green : .secondary)
        }
        .widgetLabel {
            Text(entry.cornerLabel)
                .foregroundStyle(entry.isPredicted ? .green : .primary)
        }
    }
}

#Preview(as: .accessoryCorner) {
    OBAWatchComplicationWidget()
} timeline: {
    ArrivalTimelineEntry.placeholder
}
