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

    /// Adds a new proximity alarm locally on watchOS.
    func addAlarm(_ alarm: WatchAlarmItem) {
        var current = currentAlarms()
        if !current.contains(where: { $0.stopID == alarm.stopID && $0.routeShortName == alarm.routeShortName }) {
            current.append(alarm)
            do {
                let data = try JSONEncoder().encode(current)
                WatchAppState.userDefaults.set(data, forKey: storageKey)
                
                // Schedule local background notification
                AlarmHapticScheduler.shared.scheduleFutureBackgroundNotification(for: alarm)
                
                NotificationCenter.default.post(name: Self.alarmsUpdatedNotification, object: nil)
                
                // Sync to phone
                let message: [String: Any] = ["alarms": current.map { item -> [String: Any] in
                    (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any]) ?? [:]
                }]
                _ = WatchAppState.shared.sendMessageToPhone(message)
            } catch {
                Logger.error("Failed to add alarm: \(error)")
            }
        }
    }

    /// Removes a proximity alarm locally on watchOS.
    func removeAlarm(stopID: OBAStopID, routeShortName: String?) {
        var current = currentAlarms()
        if let idx = current.firstIndex(where: { $0.stopID == stopID && $0.routeShortName == routeShortName }) {
            let item = current[idx]
            AlarmHapticScheduler.shared.cancelNotification(for: item.id)
            current.remove(at: idx)
            do {
                let data = try JSONEncoder().encode(current)
                WatchAppState.userDefaults.set(data, forKey: storageKey)
                NotificationCenter.default.post(name: Self.alarmsUpdatedNotification, object: nil)
                
                // Sync to phone
                let message: [String: Any] = ["alarms": current.map { item -> [String: Any] in
                    (try? JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any]) ?? [:]
                }]
                _ = WatchAppState.shared.sendMessageToPhone(message)
            } catch {
                Logger.error("Failed to remove alarm: \(error)")
            }
        }
    }

    /// Checks if a stop/route combo has an active proximity alarm.
    func hasAlarm(stopID: OBAStopID, routeShortName: String?) -> Bool {
        return currentAlarms().contains(where: { $0.stopID == stopID && $0.routeShortName == routeShortName })
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
