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

@MainActor
class BookmarksViewModel: ObservableObject {
    @Published var bookmarks: [WatchBookmark] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// The user's current location, injected by the view so bookmarks can be
    /// sorted by proximity. When `nil`, alphabetical ordering is used instead.
    var currentLocation: CLLocation?
    
    // Shared storage key that can be written by the iOS app via app group.
    private let storageKey = "watch.bookmarks"
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadBookmarks()

        // Listen for external updates from the sync manager (iPhone → watch).
        NotificationCenter.default.publisher(for: BookmarksSyncManager.bookmarksUpdatedNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadBookmarks()
            }
            .store(in: &cancellables)
    }
    
    func loadBookmarks(from defaults: UserDefaults = WatchAppState.userDefaults) {
        guard let data = defaults.data(forKey: storageKey) else {
            bookmarks = []
            return
        }

        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([WatchBookmark].self, from: data)
            bookmarks = sort(decoded)
        } catch {
            Logger.error("Failed to decode bookmarks: \(error)")
            errorMessage = OBALoc("bookmarks.load_error", value: "Failed to load bookmarks.", comment: "Error loading bookmarks")
        }
    }

    /// Sort bookmarks by distance from `currentLocation` when available,
    /// or alphabetically by name as a fallback.
    private func sort(_ items: [WatchBookmark]) -> [WatchBookmark] {
        guard let location = currentLocation else {
            return items.sorted { $0.name < $1.name }
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

