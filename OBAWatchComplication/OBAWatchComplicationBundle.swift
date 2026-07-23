//
//  OBAWatchComplicationBundle.swift
//  OBAWatchComplication
//
//  Created by Prince Yadav on 31/12/25.
//

import WidgetKit
import SwiftUI

/// Root WidgetKit widget that serves all three complication families
/// (circular, rectangular, corner) for the OneBusAway watch face.
struct OBAWatchComplicationWidget: Widget {

    static let kind = "OBAWatchArrivalComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ArrivalTimelineProvider()) { entry in
            OBAWatchComplicationEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("OneBusAway")
        .description("Shows the next arrival for your first bookmarked stop.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

/// Routes each WidgetFamily to the correct face view.
struct OBAWatchComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ArrivalTimelineEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplication(entry: entry)
        case .accessoryRectangular:
            RectangularComplication(entry: entry)
        case .accessoryCorner:
            CornerComplication(entry: entry)
        case .accessoryInline:
            InlineComplication(entry: entry)
        default:
            CircularComplication(entry: entry)
        }
    }
}

@main
struct OBAWatchComplicationBundle: WidgetBundle {
    var body: some Widget {
        OBAWatchComplicationWidget()
    }
}
