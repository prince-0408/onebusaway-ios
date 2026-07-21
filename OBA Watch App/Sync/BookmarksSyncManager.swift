import Foundation
import WatchConnectivity
import OBAKitCore

/// Handles incoming bookmark data from the paired iPhone.
final class BookmarksSyncManager {
    static let shared = BookmarksSyncManager()

    /// Notification fired whenever new bookmark data has been written.
    static let bookmarksUpdatedNotification = Notification.Name("BookmarksUpdated")

    /// Storage key used by BookmarksViewModel.
    private let storageKey = "watch.bookmarks"

    private init() {}

    /// Updates local bookmarks from data received via WatchConnectivity.
    func updateBookmarks(_ bookmarks: [[String: Any]]) {
        print("[WatchOS Debug] BookmarksSyncManager.updateBookmarks called with \(bookmarks.count) raw bookmarks")
        guard !bookmarks.isEmpty else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: bookmarks, options: [])
            // We decode to [WatchBookmark] first to ensure compatibility, then encode back to Data
            // to match what BookmarksViewModel expects.
            let decoded = try JSONDecoder().decode([WatchBookmark].self, from: data)
            print("[WatchOS Debug] Decoded \(decoded.count) WatchBookmarks: \(decoded.map { $0.name })")
            let encodedData = try JSONEncoder().encode(decoded)
            
            WatchAppState.userDefaults.set(encodedData, forKey: storageKey)
            WatchAppState.userDefaults.synchronize()
            print("[WatchOS Debug] Saved \(decoded.count) bookmarks to WatchAppState.userDefaults under key '\(storageKey)'")
            NotificationCenter.default.post(name: Self.bookmarksUpdatedNotification, object: nil)
        } catch {
            print("[WatchOS Debug] updateBookmarks failed decoding: \(error)")
            Logger.error("updateBookmarks failed: \(error). Preserving existing stored data.")
            NotificationCenter.default.post(name: Self.bookmarksUpdatedNotification, object: nil)
        }
    }

    /// Retrieves the current list of bookmarks.
    func getBookmarks() -> [WatchBookmark] {
        if let data = WatchAppState.userDefaults.data(forKey: storageKey) {
            do {
                let decoded = try JSONDecoder().decode([WatchBookmark].self, from: data)
                print("[WatchOS Debug] getBookmarks found \(decoded.count) bookmarks in UserDefaults")
                if !decoded.isEmpty {
                    return decoded
                }
            } catch {
                print("[WatchOS Debug] getBookmarks failed decoding UserDefaults data: \(error)")
                Logger.error("Failed to decode bookmarks: \(error)")
            }
        } else {
            print("[WatchOS Debug] getBookmarks: No data in UserDefaults for key '\(storageKey)'")
        }

        // Fallback: check WCSession receivedApplicationContext directly
        if WCSession.isSupported() {
            let context = WCSession.default.receivedApplicationContext
            print("[WatchOS Debug] getBookmarks checking receivedApplicationContext keys: \(context.keys)")
            if let bookmarksArray = context["bookmarks"] as? [[String: Any]], !bookmarksArray.isEmpty,
               let jsonData = try? JSONSerialization.data(withJSONObject: bookmarksArray, options: []),
               let decoded = try? JSONDecoder().decode([WatchBookmark].self, from: jsonData) {
                print("[WatchOS Debug] getBookmarks found \(decoded.count) bookmarks in receivedApplicationContext")
                return decoded
            }
        }

        return []
    }
}
