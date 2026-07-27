//
//  BookmarksViewModel.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation
import OBAKitCore

struct WatchBookmarkGroup: Identifiable, Sendable {
    var id: String { name }
    let name: String
    let items: [WatchBookmark]
}

@MainActor
class BookmarksViewModel: ObservableObject {
    @Published var bookmarks: [WatchBookmark] = [] {
        didSet {
            updateGroupedBookmarks()
        }
    }
    @Published var groupedBookmarks: [WatchBookmarkGroup] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// The user's current location, injected by the view so bookmarks can be
    /// sorted by proximity. When `nil`, alphabetical ordering is used instead.
    var currentLocation: CLLocation?
    
    var isViewActive: Bool = false
    
    // Shared storage key that can be written by the iOS app via app group.
    private let storageKey = "watch.bookmarks"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadBookmarks()

        // Listen for external updates from the sync manager (iPhone → watch).
        NotificationCenter.default.publisher(for: BookmarksSyncManager.bookmarksUpdatedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isViewActive else { return }
                self.loadBookmarks()
            }
            .store(in: &cancellables)
    }
    
    func loadBookmarks(from defaults: UserDefaults = WatchAppState.userDefaults) {
        print("[WatchOS Debug] BookmarksViewModel.loadBookmarks called")
        let syncedBookmarks = BookmarksSyncManager.shared.getBookmarks()
        if !syncedBookmarks.isEmpty {
            print("[WatchOS Debug] BookmarksViewModel loaded \(syncedBookmarks.count) synced bookmarks")
            bookmarks = sort(syncedBookmarks)
            return
        }

        guard let data = defaults.data(forKey: storageKey) else {
            print("[WatchOS Debug] BookmarksViewModel: no data in defaults")
            bookmarks = []
            return
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([WatchBookmark].self, from: data)
            print("[WatchOS Debug] BookmarksViewModel loaded \(decoded.count) bookmarks directly from defaults")
            bookmarks = sort(decoded)
        } catch {
            print("[WatchOS Debug] BookmarksViewModel failed to decode defaults data: \(error)")
            Logger.error("Failed to decode bookmarks: \(error)")
            errorMessage = OBALoc("bookmarks.load_error", value: "Failed to load bookmarks.", comment: "Error loading bookmarks")
        }
    }

    /// Deletes bookmarks from the local watch store and triggers a refresh.
    func deleteBookmarks(at offsets: IndexSet, from items: [WatchBookmark]) {
        for index in offsets {
            guard index < items.count else { continue }
            let bookmark = items[index]
            BookmarksSyncManager.shared.removeBookmark(stopID: bookmark.stopID, routeShortName: bookmark.routeShortName)
        }
        loadBookmarks()
    }

    private func updateGroupedBookmarks() {
        guard !bookmarks.isEmpty else {
            groupedBookmarks = []
            return
        }

        // Group by groupName
        let hasGroups = bookmarks.contains { $0.groupName != nil }
        if !hasGroups {
            groupedBookmarks = [WatchBookmarkGroup(name: OBALoc("common.bookmarks", value: "Bookmarks", comment: "Default bookmarks group name"), items: bookmarks)]
            return
        }

        var groupDict: [String: [WatchBookmark]] = [:]
        var ungrouped: [WatchBookmark] = []

        for bookmark in bookmarks {
            if let group = bookmark.groupName, !group.isEmpty {
                groupDict[group, default: []].append(bookmark)
            } else {
                ungrouped.append(bookmark)
            }
        }

        var result: [WatchBookmarkGroup] = []

        // Add named groups sorted by minimum sortOrder or name
        let sortedGroupNames = groupDict.keys.sorted { name1, name2 in
            let sort1 = groupDict[name1]?.compactMap { $0.sortOrder }.min() ?? Int.max
            let sort2 = groupDict[name2]?.compactMap { $0.sortOrder }.min() ?? Int.max
            if sort1 != sort2 { return sort1 < sort2 }
            return name1 < name2
        }

        for name in sortedGroupNames {
            if let items = groupDict[name] {
                let sortedItems = items.sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
                result.append(WatchBookmarkGroup(name: name, items: sortedItems))
            }
        }

        if !ungrouped.isEmpty {
            let sortedUngrouped = ungrouped.sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
            result.append(WatchBookmarkGroup(name: OBALoc("bookmarks.ungrouped", value: "Other Bookmarks", comment: "Ungrouped bookmarks section title"), items: sortedUngrouped))
        }

        groupedBookmarks = result
    }

    /// Updates location and re-sorts current bookmarks without re-querying disk.
    func updateCurrentLocation(_ location: CLLocation?) {
        self.currentLocation = location
        guard isViewActive else { return }
        if !bookmarks.isEmpty {
            self.bookmarks = sort(bookmarks)
        }
    }

    /// Sort bookmarks by distance from `currentLocation` when available,
    /// or by sortOrder / name as a fallback.
    private func sort(_ items: [WatchBookmark]) -> [WatchBookmark] {
        guard let location = currentLocation else {
            return items.sorted { a, b in
                if let sa = a.sortOrder, let sb = b.sortOrder, sa != sb {
                    return sa < sb
                }
                return a.name < b.name
            }
        }
        return items.sorted { a, b in
            let da = distance(of: a, from: location)
            let db = distance(of: b, from: location)
            return da < db
        }
    }

    private func distance(of bookmark: WatchBookmark, from location: CLLocation) -> CLLocationDistance {
        guard let stop = bookmark.stop else {
            // No coordinate available — treat as very far so it sorts to the bottom.
            return .greatestFiniteMagnitude
        }
        let stopLocation = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
        return stopLocation.distance(from: location)
    }
    
    func refreshData() async {
        // For now, bookmarks are stored locally on the watch or provided by
        // a companion sync process on iPhone. This simply reloads from
        // shared storage. The iOS app can update the same key via an
        // app-group UserDefaults and the watch will pick it up here.
        loadBookmarks()
    }

    func addBookmark(stop: OBAStop,
                     routeShortName: String? = nil,
                     tripHeadsign: String? = nil) {
        let bookmark = WatchBookmark(
            id: UUID(),
            stopID: stop.id,
            name: stop.name,
            routeShortName: routeShortName,
            tripHeadsign: tripHeadsign,
            stop: stop
        )

        var current = bookmarks
        current.removeAll { $0.stopID == bookmark.stopID }
        current.append(bookmark)
        bookmarks = sort(current)

        do {
            let data = try JSONEncoder().encode(bookmarks)
            WatchAppState.userDefaults.set(data, forKey: storageKey)
        } catch {
            errorMessage = OBALoc("bookmarks.save_error", value: "Failed to save bookmark.", comment: "Error saving bookmark")
        }
    }
}

