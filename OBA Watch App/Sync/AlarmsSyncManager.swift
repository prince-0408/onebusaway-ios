import Foundation
import OBAKitCore

final class AlarmsSyncManager {
    static let shared = AlarmsSyncManager()
    static let alarmsUpdatedNotification = Notification.Name("AlarmsUpdated")
    private let storageKey = "watch.alarms"

    private init() {
    }

    func currentAlarms() -> [WatchAlarmItem] {
        guard let data = WatchAppState.userDefaults.data(forKey: storageKey) else { return [] }
        do {
            return try JSONDecoder().decode([WatchAlarmItem].self, from: data)
        } catch {
            Logger.error("Failed to decode alarms: \(error)")
            return []
        }
    }

    /// Updates local alarms from data received via WatchConnectivity.
    func updateAlarms(_ alarms: [[String: Any]]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: alarms, options: [])
            let decoded = try JSONDecoder().decode([WatchAlarmItem].self, from: data)
            let encodedData = try JSONEncoder().encode(decoded)
            
            WatchAppState.userDefaults.set(encodedData, forKey: storageKey)
            
            // Schedule background local notifications for each future alarm
            for alarm in decoded {
                AlarmHapticScheduler.shared.scheduleFutureBackgroundNotification(for: alarm)
            }

            NotificationCenter.default.post(name: Self.alarmsUpdatedNotification, object: nil)
        } catch {
            Logger.error("updateAlarms failed: \(error). Clearing stale data.")
            WatchAppState.userDefaults.removeObject(forKey: storageKey)
            NotificationCenter.default.post(name: Self.alarmsUpdatedNotification, object: nil)
        }
    }

    /// Deletes alarms at specified offsets and cancels associated background local notifications.
    func deleteAlarm(at offsets: IndexSet) {
        var current = currentAlarms()
        for idx in offsets {
            if idx < current.count {
                let item = current[idx]
                AlarmHapticScheduler.shared.cancelNotification(for: item.id)
            }
        }
        current.remove(atOffsets: offsets)
        do {
            let data = try JSONEncoder().encode(current)
            WatchAppState.userDefaults.set(data, forKey: storageKey)
            NotificationCenter.default.post(name: Self.alarmsUpdatedNotification, object: nil)
        } catch {
            Logger.error("Failed to delete alarm: \(error)")
        }
    }
}
