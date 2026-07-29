//
//  AlarmHapticScheduler.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import WatchKit
import CoreLocation
import UserNotifications
import OBAKitCore

/// Polls active alarms every 30 seconds and fires distinct wrist haptics and local notifications
/// when departure times approach OR when entering a GPS destination stop geofence.
///
/// Supported Alarm Modes:
/// - **Departure Time Alarm**: Fires custom offset warning (e.g. 2m, 5m, 10m, 15m before departure) + 1m confirmation confirmation.
/// - **GPS Destination Geofence Alarm**: Triggers strong wake-up haptics when wrist GPS enters within target radius (e.g., 100m, 200m, 500m) of destination stop.
@MainActor
final class AlarmHapticScheduler: NSObject, WKExtendedRuntimeSessionDelegate {

    static let shared = AlarmHapticScheduler()

    // MARK: - Private State

    private var timer: Timer?
    private var runtimeSession: WKExtendedRuntimeSession?

    private var firedKeys: Set<String> {
        get { Set(Self.defaults.stringArray(forKey: Self.firedKeysStorageKey) ?? []) }
        set { Self.defaults.set(Array(newValue), forKey: Self.firedKeysStorageKey) }
    }

    private static let firedKeysStorageKey = "watch.haptic_scheduler.fired_keys"
    private static let defaults = WatchAppState.userDefaults

    // MARK: - Lifecycle

    private override init() {
        super.init()
        requestNotificationPermission()
    }

    /// Request local notification authorization on watchOS.
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.error("Local notification authorization failed: \(error)")
            }
        }
    }

    /// Start the 30-second polling loop. Safe to call multiple times.
    func start() {
        guard timer == nil else { return }
        tick()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    /// Stop the polling loop.
    func stop() {
        timer?.invalidate()
        timer = nil
        stopExtendedRuntimeSession()
    }

    /// Start WKExtendedRuntimeSession to maintain background execution while wrist is down.
    func startExtendedRuntimeSession() {
        guard runtimeSession == nil else { return }
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        runtimeSession = session
    }

    /// Stop the background extended runtime session.
    func stopExtendedRuntimeSession() {
        runtimeSession?.invalidate()
        runtimeSession = nil
    }

    /// Plays a test haptic sequence so users can preview departure or geofence alert feedback.
    func playTestHaptic(type: WatchAlarmItem.AlarmType = .departureTime) {
        switch type {
        case .departureTime:
            WKInterfaceDevice.current().play(.directionDown)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                WKInterfaceDevice.current().play(.success)
            }
        case .destinationGeofence:
            WKInterfaceDevice.current().play(.failure)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                WKInterfaceDevice.current().play(.retry)
            }
        }
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    nonisolated func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Logger.info("Extended runtime session started for active alarm tracking")
    }

    nonisolated func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Logger.info("Extended runtime session will expire")
    }

    nonisolated func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        Task { @MainActor in
            self.runtimeSession = nil
        }
    }

    // MARK: - Internal Engine Logic

    private func tick() {
        let alarms = AlarmsSyncManager.shared.currentAlarms()
        guard !alarms.isEmpty else {
            stopExtendedRuntimeSession()
            return
        }

        startExtendedRuntimeSession()

        let now = Date()
        let currentLocation = WatchAppState.shared.currentLocation
        var fired = firedKeys

        for alarm in alarms {
            switch alarm.alarmType {
            case .departureTime:
                processDepartureTimeAlarm(alarm, now: now, fired: &fired)
            case .destinationGeofence:
                processDestinationGeofenceAlarm(alarm, currentLocation: currentLocation, fired: &fired)
            }
        }

        firedKeys = fired

        // Prune fired keys for alarms no longer in active list
        let activeIDs = Set(alarms.map { $0.id })
        let pruned = fired.filter { key in activeIDs.contains(where: { key.hasPrefix($0) }) }
        if pruned.count != fired.count {
            firedKeys = pruned
        }
    }

    private func processDepartureTimeAlarm(_ alarm: WatchAlarmItem, now: Date, fired: inout Set<String>) {
        guard let departure = alarm.scheduledTime else { return }

        let minutesAway = departure.timeIntervalSince(now) / 60.0
        guard minutesAway >= 0, minutesAway <= 30 else { return }

        let customOffset = alarm.offsetMinutes
        let offsetKey = "\(alarm.id)-\(customOffset)min"
        let oneMinKey  = "\(alarm.id)-1min"

        // Custom threshold warning (e.g., ≤ 5 min or 10 min)
        if minutesAway <= Double(customOffset), !fired.contains(offsetKey) {
            WKInterfaceDevice.current().play(.directionDown)
            scheduleLocalNotification(alarm: alarm, minutesLeft: customOffset)
            fired.insert(offsetKey)
        }

        // ≤ 1 min -> strong arrival confirmation
        if minutesAway <= 1, !fired.contains(oneMinKey) {
            WKInterfaceDevice.current().play(.success)
            scheduleLocalNotification(alarm: alarm, minutesLeft: 1)
            fired.insert(oneMinKey)
        }
    }

    private func processDestinationGeofenceAlarm(_ alarm: WatchAlarmItem, currentLocation: CLLocation?, fired: inout Set<String>) {
        guard let currentLocation = currentLocation,
              let lat = alarm.latitude,
              let lon = alarm.longitude else { return }

        let stopLocation = CLLocation(latitude: lat, longitude: lon)
        let distanceMeters = currentLocation.distance(from: stopLocation)
        let targetRadius = alarm.geofenceRadiusMeters

        let geofenceKey = "\(alarm.id)-geofence"

        if distanceMeters <= targetRadius, !fired.contains(geofenceKey) {
            // Strong wake-up vibration pattern for destination arrival
            WKInterfaceDevice.current().play(.failure)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                WKInterfaceDevice.current().play(.retry)
            }

            scheduleGeofenceLocalNotification(alarm: alarm, distanceMeters: Int(distanceMeters))
            fired.insert(geofenceKey)
        }
    }

    private func scheduleLocalNotification(alarm: WatchAlarmItem, minutesLeft: Int) {
        let content = UNMutableNotificationContent()
        let route = alarm.routeShortName ?? OBALoc("common.bus", value: "Bus", comment: "Default bus label")

        content.title = String(format: OBALoc("alarms.arriving_title_fmt", value: "%@ Arriving Soon", comment: "Alarm arrival title"), route)
        if minutesLeft <= 1 {
            content.body = String(format: OBALoc("alarms.arriving_now_body_fmt", value: "%@ to %@ is arriving in 1 min!", comment: "Alarm 1m body"), route, alarm.headsign ?? "")
        } else {
            content.body = String(format: OBALoc("alarms.arriving_offset_body_fmt", value: "%@ to %@ is %d minutes away.", comment: "Alarm offset body"), route, alarm.headsign ?? "", minutesLeft)
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: "\(alarm.id)-\(minutesLeft)m", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to add local notification: \(error)")
            }
        }
    }

    private func scheduleGeofenceLocalNotification(alarm: WatchAlarmItem, distanceMeters: Int) {
        let content = UNMutableNotificationContent()
        let stopOrRoute = alarm.routeShortName ?? alarm.headsign ?? OBALoc("common.stop", value: "Destination Stop", comment: "Destination stop label")

        content.title = OBALoc("alarms.geofence_title", value: "Approaching Destination", comment: "Geofence arrival title")
        content.body = String(format: OBALoc("alarms.geofence_body_fmt", value: "You are within %dm of %@. Get ready to step off!", comment: "Geofence arrival body"), distanceMeters, stopOrRoute)
        content.sound = .default

        let request = UNNotificationRequest(identifier: "\(alarm.id)-geofence_alert", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to add geofence local notification: \(error)")
            }
        }
    }

    /// Schedules a background local notification for a future alarm via UNTimeIntervalNotificationTrigger.
    func scheduleFutureBackgroundNotification(for alarm: WatchAlarmItem) {
        guard let scheduledTime = alarm.scheduledTime else { return }
        let leadSeconds = Double(alarm.offsetMinutes * 60)
        let interval = scheduledTime.timeIntervalSinceNow - leadSeconds
        guard interval > 5.0 else { return }

        let content = UNMutableNotificationContent()
        let route = alarm.routeShortName ?? OBALoc("common.bus", value: "Bus", comment: "Default bus label")
        content.title = String(format: OBALoc("alarms.arriving_title_fmt", value: "%@ Arriving Soon", comment: "Alarm arrival title"), route)
        content.body = String(format: OBALoc("alarms.arriving_offset_body_fmt", value: "%@ to %@ is arriving in %d min.", comment: "Alarm offset body"), route, alarm.headsign ?? "", alarm.offsetMinutes)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "alarm_bg_\(alarm.id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancels all pending notification triggers for an alarm ID.
    func cancelNotification(for alarmID: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["alarm_bg_\(alarmID)", "\(alarmID)-5m", "\(alarmID)-1m", "\(alarmID)-geofence_alert"])
    }
}
