//
//  ConnectionGuideView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

struct ConnectionGuideView: View {
    let context: TransferContext
    let stopName: String?
    let connectingArrival: OBAArrival?

    enum ConnectionFeasibility {
        case comfortable(minutes: Int)
        case tight(minutes: Int)
        case missed(minutes: Int)

        var title: String {
            switch self {
            case .comfortable(let mins):
                return "\(mins)m Window • Comfortable"
            case .tight(let mins):
                return "\(mins)m Window • Tight Transfer"
            case .missed:
                return "Missed Connection"
            }
        }

        var badgeColor: Color {
            switch self {
            case .comfortable: return .green
            case .tight: return .orange
            case .missed: return .red
            }
        }

        var iconName: String {
            switch self {
            case .comfortable: return "checkmark.circle.fill"
            case .tight: return "exclamationmark.triangle.fill"
            case .missed: return "xmark.circle.fill"
            }
        }
    }

    private var feasibility: ConnectionFeasibility {
        guard let departureDate = connectingArrival?.arrivalTime else {
            return .comfortable(minutes: 5)
        }
        let diff = context.minutesUntilDeparture(from: departureDate)
        if diff < 0 {
            return .missed(minutes: abs(diff))
        } else if diff <= 6 {
            return .tight(minutes: diff)
        } else {
            return .comfortable(minutes: diff)
        }
    }

    private var arrivalTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: context.arrivalTime)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Connection Feasibility Header Pill
                HStack(spacing: 6) {
                    Image(systemName: feasibility.iconName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(feasibility.badgeColor)
                    
                    Text(feasibility.title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(feasibility.badgeColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(feasibility.badgeColor.opacity(0.18))
                )

                // Timeline Card
                VStack(alignment: .leading, spacing: 10) {
                    // Step 1: Arriving Trip
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.brand)
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(OBALoc("connection_guide.arrive_title", value: "Arrive on Origin Bus", comment: "Step 1 title"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(context.fromRouteDisplay)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(String(format: OBALoc("connection_guide.eta_fmt", value: "ETA: %@", comment: "ETA label"), arrivalTimeString))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Vertical Connection Line
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                            .frame(width: 2, height: 18)
                            .padding(.leading, 4)
                        
                        Text(OBALoc("connection_guide.transfer_buffer", value: "Transfer / Walk Window", comment: "Transfer buffer text"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    // Step 2: Connecting Trip
                    HStack(spacing: 10) {
                        Circle()
                            .fill(feasibility.badgeColor)
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(OBALoc("connection_guide.depart_title", value: "Board Connecting Line", comment: "Step 2 title"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            if let connecting = connectingArrival {
                                Text("\(connecting.routeShortName ?? "") - \(connecting.headsign ?? "")")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Text(connecting.timeString(at: Date()))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(feasibility.badgeColor)
                            } else {
                                Text(stopName ?? OBALoc("common.connecting_stop", value: "Connecting Stop", comment: "Connecting stop label"))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.08))
                )

                // Arm Alarm Action
                if let connecting = connectingArrival {
                    NavigationLink {
                        AlarmSetupView(
                            stopID: connecting.stopID,
                            stopName: stopName,
                            routeShortName: connecting.routeShortName,
                            headsign: connecting.headsign,
                            departureTime: connecting.arrivalTime
                        )
                    } label: {
                        Label(OBALoc("connection_guide.arm_alarm", value: "Set Transfer Alarm", comment: "Set alarm for transfer button"), systemImage: "bell.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .navigationTitle(OBALoc("connection_guide.title", value: "Transfer Guide", comment: "Transfer guide screen title"))
    }
}
