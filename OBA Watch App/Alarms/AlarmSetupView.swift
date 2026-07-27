//
//  AlarmSetupView.swift
//  OBAWatch Watch App
//

import SwiftUI
import OBAKitCore

struct AlarmSetupView: View {
    @Environment(\.dismiss) private var dismiss
    
    let stopID: OBAStopID
    let stopName: String?
    let routeShortName: String?
    let headsign: String?
    let departureTime: Date?

    @State private var hasAlarm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: hasAlarm ? "bell.fill" : "bell")
                    .font(.system(size: 36))
                    .foregroundColor(hasAlarm ? .orange : .secondary)

                VStack(spacing: 2) {
                    Text(routeShortName ?? OBALoc("common.bus", value: "Bus", comment: "Default bus label"))
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let headsign = headsign, !headsign.isEmpty {
                        Text(headsign)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let stopName = stopName {
                        Text(stopName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if let time = departureTime {
                    HStack(spacing: 4) {
                        Text(OBALoc("alarm_setup.departs", value: "Departs:", comment: "Departure label"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(time, style: .time)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                }

                if hasAlarm {
                    Button(role: .destructive) {
                        AlarmsSyncManager.shared.removeAlarm(stopID: stopID, routeShortName: routeShortName)
                        WatchFeedbackGenerator.shared.success()
                        dismiss()
                    } label: {
                        Label(OBALoc("alarms.remove_alarm", value: "Remove Alarm", comment: "Remove proximity alarm"), systemImage: "bell.slash.fill")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        let alarm = WatchAlarmItem(
                            id: UUID().uuidString,
                            stopID: stopID,
                            routeShortName: routeShortName,
                            headsign: headsign ?? "",
                            scheduledTime: departureTime ?? Date()
                        )
                        AlarmsSyncManager.shared.addAlarm(alarm)
                        WatchFeedbackGenerator.shared.success()
                        dismiss()
                    } label: {
                        Label(OBALoc("alarms.set_alarm", value: "Set Proximity Alarm", comment: "Set proximity alarm"), systemImage: "bell.fill")
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Text(OBALoc("alarm_setup.details", value: "Wrist haptics will alert you 5m and 1m before departure.", comment: "Proximity alarm haptics info"))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .navigationTitle(OBALoc("alarms.title", value: "Alarms", comment: "Alarms title"))
        .onAppear {
            hasAlarm = AlarmsSyncManager.shared.hasAlarm(stopID: stopID, routeShortName: routeShortName)
        }
    }
}
