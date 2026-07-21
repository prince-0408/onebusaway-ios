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
            let decoded = try JSONDecoder().decode([WatchBookmark].self, from: data)
            print("[WatchOS Debug] Decoded \(decoded.count) WatchBookmarks: \(decoded.map { $0.name })")
            let encodedData = try JSONEncoder().encode(decoded)
            
            WatchAppState.userDefaults.set(encodedData, forKey: storageKey)
            WatchAppState.userDefaults.synchronize()
            UserDefaults.standard.set(encodedData, forKey: storageKey)
            UserDefaults.standard.synchronize()

            print("[WatchOS Debug] Saved \(decoded.count) bookmarks to UserDefaults under key '\(storageKey)'")
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
                if !decoded.isEmpty {
                    print("[WatchOS Debug] getBookmarks found \(decoded.count) bookmarks in WatchAppState.userDefaults")
                    return decoded
                }
            } catch {
                print("[WatchOS Debug] getBookmarks failed decoding WatchAppState.userDefaults: \(error)")
            }
        }

        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoded = try JSONDecoder().decode([WatchBookmark].self, from: data)
                if !decoded.isEmpty {
                    print("[WatchOS Debug] getBookmarks found \(decoded.count) bookmarks in UserDefaults.standard")
                    return decoded
                }
            } catch {
                print("[WatchOS Debug] getBookmarks failed decoding UserDefaults.standard: \(error)")
            }
        }

        // Fallback: check WCSession receivedApplicationContext directly
        if WCSession.isSupported() {
            let context = WCSession.default.receivedApplicationContext
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
