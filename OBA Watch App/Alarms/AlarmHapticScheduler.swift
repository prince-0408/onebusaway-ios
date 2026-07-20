//
//  AlarmHapticScheduler.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import WatchKit
import OBAKitCore

/// Polls the active alarm list every 30 seconds and fires distinct haptic
/// patterns on the wrist when a watched bus is approaching or arriving.
///
/// - **5 minutes before departure**: `.directionDown` (the "double-tap" feel)
/// - **1 minute before departure**: `.success` (strong confirmation vibration)
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

    private init() {}

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

            // ≤5 min → double-tap style haptic (directionDown)
            if minutesAway <= 5, !fired.contains(fiveMinKey) {
                WKInterfaceDevice.current().play(.directionDown)
                fired.insert(fiveMinKey)
            }

            // ≤1 min → strong arrival-confirmation haptic (success)
            if minutesAway <= 1, !fired.contains(oneMinKey) {
                WKInterfaceDevice.current().play(.success)
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
}
