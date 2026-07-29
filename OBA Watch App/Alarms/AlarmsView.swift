import SwiftUI
import CoreLocation
import OBAKitCore

struct AlarmsView: View {
    @State private var alarms: [WatchAlarmItem] = AlarmsSyncManager.shared.currentAlarms()
    @State private var infoMessage: String?

    var body: some View {
        List {
            if alarms.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(OBALoc("alarms.no_alarms", value: "No Active Alarms", comment: "Empty state title for alarms"))
                        .font(.headline)
                    Text(OBALoc("alarms.empty_subtitle", value: "Set an alarm from any stop arrival row.", comment: "Empty state subtitle for alarms"))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ForEach(alarms) { alarm in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(alarm.routeShortName ?? OBALoc("alarms.default_title", value: "Alarm", comment: "Default title for an alarm"))
                                .font(.headline)
                            Spacer()
                            
                            // Alarm Type Indicator Badge
                            if alarm.alarmType == .departureTime {
                                Text("\(alarm.offsetMinutes)m lead")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .clipShape(Capsule())
                            } else {
                                Text("📍 \(Int(alarm.geofenceRadiusMeters))m")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .clipShape(Capsule())
                            }
                        }

                        if let headsign = alarm.headsign, !headsign.isEmpty {
                            Text(headsign)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        // Live GPS distance for geofence alarms
                        if alarm.alarmType == .destinationGeofence,
                           let lat = alarm.latitude, let lon = alarm.longitude,
                           let userLoc = WatchAppState.shared.currentLocation {
                            let stopLoc = CLLocation(latitude: lat, longitude: lon)
                            let distance = Int(userLoc.distance(from: stopLoc))
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                                Text("\(distance)m away")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }

                        HStack {
                            Button {
                                AlarmHapticScheduler.shared.playTestHaptic(type: alarm.alarmType)
                            } label: {
                                Image(systemName: "waveform")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                let ok = DeepLinkSyncManager.shared.openStopOnPhone(stopID: alarm.stopID)
                                if !ok {
                                    infoMessage = OBALoc("deeplink.failure", value: "Unable to contact iPhone. Make sure your devices are connected.", comment: "Deep link failure")
                                }
                            } label: {
                                Image(systemName: "iphone")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    AlarmsSyncManager.shared.deleteAlarm(at: indexSet)
                }
            }
        }
        .navigationTitle(OBALoc("alarms.title", value: "Alarms", comment: "Title for alarms screen"))
        .onAppear {
            AlarmHapticScheduler.shared.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: AlarmsSyncManager.alarmsUpdatedNotification)) { _ in
            alarms = AlarmsSyncManager.shared.currentAlarms()
        }
        .alert(OBALoc("common.info", value: "Info", comment: "Alert title for information"), isPresented: Binding(
            get: { infoMessage != nil },
            set: { if !$0 { infoMessage = nil } }
        )) {
            Button(OBALoc("common.ok", value: "OK", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
    }
}

#Preview {
    AlarmsView()
}
