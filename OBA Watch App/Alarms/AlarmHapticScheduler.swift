//
//  AlarmHapticScheduler.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import WatchKit
import UserNotifications
import OBAKitCore

/// Polls the active alarm list every 30 seconds and fires distinct haptic
/// patterns on the wrist when a watched bus is approaching or arriving.
/// Also posts native watchOS local notifications for wrist alerts.
///
/// - **5 minutes before departure**: `.directionDown` (the "double-tap" feel) + 5m Notification
/// - **1 minute before departure**: `.success` (strong confirmation vibration) + 1m Notification
///
/// Each alarm+threshold combo fires at most once, tracked via `UserDefaults`
/// to prevent repeated haptics across polls.
@MainActor
final class AlarmHapticScheduler {

    static let shared = AlarmHapticScheduler()

    // MARK: - Private State

    private var timer: Timer?

    private var firedKeys: Set<String> {
        get { Set(Self.defaults.stringArray(forKey: Self.firedKeysStorageKey) ?? []) }
        set { Self.defaults.set(Array(newValue), forKey: Self.firedKeysStorageKey) }
    }

    private static let firedKeysStorageKey = "watch.haptic_scheduler.fired_keys"
    private static let defaults = WatchAppState.userDefaults

    // MARK: - Lifecycle

    private init() {
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

    /// Stop the polling loop (call when app goes to background).
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Internal

    private func tick() {
        let alarms = AlarmsSyncManager.shared.currentAlarms()
        guard !alarms.isEmpty else { return }

        let now = Date()
        var fired = firedKeys

        for alarm in alarms {
            guard let departure = alarm.scheduledTime else { continue }

            let minutesAway = departure.timeIntervalSince(now) / 60.0

            // Only look at buses arriving within the next 10 minutes.
            guard minutesAway >= 0, minutesAway <= 10 else { continue }

            let fiveMinKey = "\(alarm.id)-5min"
            let oneMinKey  = "\(alarm.id)-1min"

            // ≤5 min → double-tap style haptic (directionDown) + 5m Notification
            if minutesAway <= 5, !fired.contains(fiveMinKey) {
                WKInterfaceDevice.current().play(.directionDown)
                scheduleLocalNotification(alarm: alarm, minutesLeft: 5)
                fired.insert(fiveMinKey)
            }

            // ≤1 min → strong arrival-confirmation haptic (success) + 1m Notification
            if minutesAway <= 1, !fired.contains(oneMinKey) {
                WKInterfaceDevice.current().play(.success)
                scheduleLocalNotification(alarm: alarm, minutesLeft: 1)
                fired.insert(oneMinKey)
            }
        }

        firedKeys = fired

        // Prune fired keys for alarms no longer in the active list.
        let activeIDs = Set(alarms.map { $0.id })
        let pruned = fired.filter { key in activeIDs.contains(where: { key.hasPrefix($0) }) }
        if pruned.count != fired.count {
            firedKeys = pruned
        }
    }

    private func scheduleLocalNotification(alarm: WatchAlarmItem, minutesLeft: Int) {
        let content = UNMutableNotificationContent()
        let route = alarm.routeShortName ?? OBALoc("common.bus", value: "Bus", comment: "Default bus label")
        
        content.title = String(format: OBALoc("alarms.arriving_title_fmt", value: "%@ Arriving Soon", comment: "Alarm arrival title"), route)
        if minutesLeft <= 1 {
            content.body = String(format: OBALoc("alarms.arriving_now_body_fmt", value: "%@ to %@ is arriving in 1 min!", comment: "Alarm 1m body"), route, alarm.headsign ?? "")
        } else {
            content.body = String(format: OBALoc("alarms.arriving_5m_body_fmt", value: "%@ to %@ is 5 minutes away.", comment: "Alarm 5m body"), route, alarm.headsign ?? "")
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: "\(alarm.id)-\(minutesLeft)m", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.error("Failed to add local notification: \(error)")
            }
        }
    }
}
