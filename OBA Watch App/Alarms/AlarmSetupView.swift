//
//  AlarmSetupView.swift
//  OBAWatch Watch App
//

import SwiftUI
import CoreLocation
import OBAKitCore

struct AlarmSetupView: View {
    @Environment(\.dismiss) private var dismiss

    let stopID: OBAStopID
    let stopName: String?
    let routeShortName: String?
    let headsign: String?
    let departureTime: Date?
    let latitude: Double?
    let longitude: Double?

    @State private var alarmType: WatchAlarmItem.AlarmType = .departureTime
    @State private var selectedOffsetMinutes: Int = 5
    @State private var selectedGeofenceRadius: Double = 200.0
    @State private var hasAlarm = false

    init(
        stopID: OBAStopID,
        stopName: String?,
        routeShortName: String?,
        headsign: String?,
        departureTime: Date?,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.stopID = stopID
        self.stopName = stopName
        self.routeShortName = routeShortName
        self.headsign = headsign
        self.departureTime = departureTime
        self.latitude = latitude
        self.longitude = longitude
    }

    var body: some View {
        VStack(spacing: 6) {
            // Compact Header: Route & Stop Info
            HStack(spacing: 6) {
                Image(systemName: hasAlarm ? "bell.fill" : "bell.badge.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(hasAlarm ? .orange : .accentColor)

                VStack(alignment: .leading, spacing: 1) {
                    Text(routeShortName ?? OBALoc("common.bus", value: "Bus", comment: "Default bus label"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    let subTitle = headsign ?? stopName ?? ""
                    if !subTitle.isEmpty {
                        Text(subTitle)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if hasAlarm {
                VStack(spacing: 8) {
                    Text(OBALoc("alarms.active_alarm_set", value: "Active Alarm Set", comment: "Active alarm title"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)

                    Button(role: .destructive) {
                        AlarmsSyncManager.shared.removeAlarm(stopID: stopID, routeShortName: routeShortName)
                        WatchFeedbackGenerator.shared.success()
                        dismiss()
                    } label: {
                        Label(OBALoc("alarms.remove_alarm", value: "Remove Alarm", comment: "Remove alarm button"), systemImage: "bell.slash.fill")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(.bordered)

                    Button {
                        AlarmHapticScheduler.shared.playTestHaptic(type: alarmType)
                    } label: {
                        Label(OBALoc("alarm_setup.test_haptic", value: "Test Haptics", comment: "Test haptics button"), systemImage: "waveform")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            } else {
                // Segmented Mode Selector Capsule (Departure vs Geofence)
                HStack(spacing: 4) {
                    Button {
                        alarmType = .departureTime
                        WatchFeedbackGenerator.shared.selectionChanged()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9))
                            Text(OBALoc("alarm_setup.type_departure_short", value: "Departure", comment: "Departure short label"))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(alarmType == .departureTime ? Color.orange : Color.white.opacity(0.1))
                        .foregroundColor(alarmType == .departureTime ? .black : .white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        alarmType = .destinationGeofence
                        WatchFeedbackGenerator.shared.selectionChanged()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 9))
                            Text(OBALoc("alarm_setup.type_geofence_short", value: "Geofence", comment: "Geofence short label"))
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(alarmType == .destinationGeofence ? Color.brand : Color.white.opacity(0.1))
                        .foregroundColor(alarmType == .destinationGeofence ? .black : .white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                // Threshold Selector Row
                if alarmType == .departureTime {
                    HStack(spacing: 4) {
                        ForEach([2, 5, 10, 15], id: \.self) { mins in
                            Button {
                                selectedOffsetMinutes = mins
                                WatchFeedbackGenerator.shared.selectionChanged()
                            } label: {
                                Text("\(mins)m")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedOffsetMinutes == mins ? Color.orange : Color.white.opacity(0.12))
                                    .foregroundColor(selectedOffsetMinutes == mins ? .black : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach([100.0, 200.0, 500.0], id: \.self) { radius in
                            Button {
                                selectedGeofenceRadius = radius
                                WatchFeedbackGenerator.shared.selectionChanged()
                            } label: {
                                Text("\(Int(radius))m")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.vertical, 5)
                                    .frame(maxWidth: .infinity)
                                    .background(selectedGeofenceRadius == radius ? Color.brand : Color.white.opacity(0.12))
                                    .foregroundColor(selectedGeofenceRadius == radius ? .black : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)

                // Compact Action Row: Slim Set Alarm + Test Waveform Icon
                HStack(spacing: 6) {
                    Button {
                        let alarm = WatchAlarmItem(
                            id: UUID().uuidString,
                            stopID: stopID,
                            routeShortName: routeShortName,
                            headsign: headsign ?? "",
                            scheduledTime: departureTime ?? Date(),
                            status: alarmType == .departureTime ? "\(selectedOffsetMinutes)m lead" : "Within \(Int(selectedGeofenceRadius))m",
                            alarmType: alarmType,
                            offsetMinutes: selectedOffsetMinutes,
                            latitude: latitude,
                            longitude: longitude,
                            geofenceRadiusMeters: selectedGeofenceRadius
                        )
                        AlarmsSyncManager.shared.addAlarm(alarm)
                        AlarmHapticScheduler.shared.startExtendedRuntimeSession()
                        WatchFeedbackGenerator.shared.success()
                        dismiss()
                    } label: {
                        Text(
                            alarmType == .departureTime ?
                                OBALoc("alarms.set_time_alarm", value: "Set Alarm", comment: "Set time alarm button") :
                                OBALoc("alarms.set_geofence_alarm", value: "Set GPS Alarm", comment: "Set GPS alarm button")
                        )
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(alarmType == .departureTime ? Color.orange : Color.brand)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    // Compact Test Haptic Waveform Button
                    Button {
                        AlarmHapticScheduler.shared.playTestHaptic(type: alarmType)
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .navigationTitle(OBALoc("alarms.title", value: "Alarms", comment: "Alarms title"))
        .onAppear {
            hasAlarm = AlarmsSyncManager.shared.hasAlarm(stopID: stopID, routeShortName: routeShortName)
        }
    }
}
