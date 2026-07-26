//
//  WatchOccupancyStatusView.swift
//  OBA Watch App
//
//  Created by Prince Yadav on 26/07/26.
//

import SwiftUI
import OBAKitCore

/// Renders the vehicle occupancy status on watchOS, mirroring `OccupancyStatusView.swift` from iOS OBAKit.
/// Displays a badge with 1–3 person SF Symbols (`person.fill`) or a badge icon (`person.crop.circle.fill.badge.xmark`)
/// along with human-readable localized text.
struct WatchOccupancyStatusView: View {
    let occupancyStatus: OBAOccupancyStatus
    var realtimeData: Bool = true

    var body: some View {
        if occupancyStatus != .unknown && occupancyStatus != .noDataAvailable {
            HStack(spacing: 4) {
                iconBadge
                
                Text(descriptionText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(realtimeData ? .secondary : .secondary.opacity(0.7))
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(descriptionText)
        }
    }

    @ViewBuilder
    private var iconBadge: some View {
        HStack(spacing: 2) {
            switch occupancyStatus {
            case .empty, .manySeatsAvailable:
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
            case .fewSeatsAvailable, .standingRoomOnly:
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
            case .crushedStandingRoomOnly, .full:
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
                Image(systemName: "person.fill")
                    .font(.system(size: 9))
            case .notBoardable, .notAcceptingPassengers:
                Image(systemName: "person.crop.circle.fill.badge.xmark")
                    .font(.system(size: 9))
            case .noDataAvailable, .unknown:
                EmptyView()
            }
        }
        .foregroundColor(realtimeData ? .white.opacity(0.9) : .secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.15))
        )
    }

    private var descriptionText: String {
        let baseText: String
        switch occupancyStatus {
        case .empty:
            baseText = OBALoc("occupancy_status.empty", value: "Empty", comment: "Vehicle occupancy is zero")
        case .manySeatsAvailable:
            baseText = OBALoc("occupancy_status.many_seats_available", value: "Many seats available", comment: "Vehicle occupancy is low")
        case .fewSeatsAvailable:
            baseText = OBALoc("occupancy_status.few_seats_available", value: "Few seats available", comment: "Vehicle occupancy is medium")
        case .standingRoomOnly:
            baseText = OBALoc("occupancy_status.standing_room_only", value: "Standing room only", comment: "Vehicle occupancy is high")
        case .crushedStandingRoomOnly:
            baseText = OBALoc("occupancy_status.crushed_standing_room_only", value: "Crushed standing room only", comment: "Vehicle occupancy is very high")
        case .full:
            baseText = OBALoc("occupancy_status.full", value: "Full", comment: "Vehicle occupancy is full")
        case .notBoardable, .notAcceptingPassengers:
            baseText = OBALoc("occupancy_status.not_accepting_passengers", value: "Not accepting passengers", comment: "Vehicle is not accepting passengers")
        case .noDataAvailable, .unknown:
            baseText = OBALoc("occupancy_status.unknown", value: "Unknown", comment: "Vehicle occupancy status is unknown")
        }

        if realtimeData {
            return baseText
        } else {
            let fmt = OBALoc("occupancy_status.historical_fmt", value: "Historical: %@", comment: "Historical occupancy format")
            return String(format: fmt, baseText)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        WatchOccupancyStatusView(occupancyStatus: .manySeatsAvailable)
        WatchOccupancyStatusView(occupancyStatus: .fewSeatsAvailable)
        WatchOccupancyStatusView(occupancyStatus: .full)
        WatchOccupancyStatusView(occupancyStatus: .notAcceptingPassengers)
    }
    .padding()
}
