//
//  ArrivalTimelineProvider.swift
//  OBAWatchComplication
//
//  Created by Prince Yadav on 31/12/25.
//

import WidgetKit
import Foundation
import OBAKitCore

/// WidgetKit `TimelineProvider` that fetches the next arrival for the user's
/// first bookmarked stop and builds a 5-minute refresh timeline.
struct ArrivalTimelineProvider: TimelineProvider {

    typealias Entry = ArrivalTimelineEntry

    // MARK: - TimelineProvider

    func placeholder(in context: Context) -> ArrivalTimelineEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ArrivalTimelineEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task {
            let entry = await fetchEntry(at: Date())
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArrivalTimelineEntry>) -> Void) {
        Task {
            let now = Date()
            let entry = await fetchEntry(at: now)
            // Refresh every 5 minutes so the countdown stays accurate.
            let refreshDate = now.addingTimeInterval(5 * 60)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }

    // MARK: - Private

    /// Loads the primary bookmark from shared app-group `UserDefaults` then
    /// fetches the next scheduled arrival from the OBA API.
    private func fetchEntry(at date: Date) async -> ArrivalTimelineEntry {
        let defaults = sharedDefaults()

        // Decode the user's saved bookmarks.
        guard
            let data = defaults.data(forKey: "watch.bookmarks"),
            let bookmarks = try? JSONDecoder().decode([WatchBookmark].self, from: data),
            let primary = bookmarks.first
        else {
            return ArrivalTimelineEntry(
                date: date,
                stopName: NSLocalizedString(
                    "complication.no_bookmarks",
                    value: "No Bookmarks",
                    comment: "Placeholder when no bookmarks exist"),
                routeShortName: nil,
                arrivalDate: nil,
                isPredicted: false
            )
        }

        // Build an API client from the saved region selection.
        guard let apiClient = makeAPIClient(from: defaults) else {
            return ArrivalTimelineEntry(
                date: date,
                stopName: primary.name,
                routeShortName: primary.routeShortName,
                arrivalDate: nil,
                isPredicted: false
            )
        }

        // Fetch arrivals and pick the soonest upcoming one.
        do {
            let result = try await apiClient.fetchArrivals(for: primary.stopID)

            // OBAArrival uses minutesFromNow (Int) — filter to upcoming only.
            let upcoming = result.arrivals.filter { $0.minutesFromNow >= 0 }
            let next = upcoming.min(by: { $0.minutesFromNow < $1.minutesFromNow })

            let arrivalDate: Date? = next.map { date.addingTimeInterval(TimeInterval($0.minutesFromNow * 60)) }
            let isPredicted = next?.isPredicted ?? false
            let routeName = next?.routeShortName ?? primary.routeShortName

            return ArrivalTimelineEntry(
                date: date,
                stopName: primary.name,
                routeShortName: routeName,
                arrivalDate: arrivalDate,
                isPredicted: isPredicted
            )
        } catch {
            return ArrivalTimelineEntry(
                date: date,
                stopName: primary.name,
                routeShortName: primary.routeShortName,
                arrivalDate: nil,
                isPredicted: false
            )
        }
    }

    // MARK: - Helpers

    private func sharedDefaults() -> UserDefaults {
        if let config = Bundle.main.object(forInfoDictionaryKey: "OBAKitConfig") as? [String: Any],
           let suiteName = config["AppGroup"] as? String,
           let ud = UserDefaults(suiteName: suiteName) {
            return ud
        }
        return .standard
    }

    /// Reads the persisted region base URL and builds an `OBAURLSessionAPIClient`.
    /// Falls back to Puget Sound if no region is selected.
    private func makeAPIClient(from defaults: UserDefaults) -> OBAURLSessionAPIClient? {
        // The base URL is stored by the watch app under this key.
        let baseURLKey = "watch_region_base_url"
        let apiKey: String = {
            if let config = Bundle.main.object(forInfoDictionaryKey: "OBAKitConfig") as? [String: Any],
               let key = config["RESTServerAPIKey"] as? String {
                return key
            }
            return "org.onebusaway.iphone"
        }()

        // Try the persisted URL first, fall back to Puget Sound.
        let rawURL = defaults.string(forKey: baseURLKey) ?? "https://api.pugetsound.onebusaway.org/"
        guard let baseURL = URL(string: rawURL) else { return nil }

        let config = OBAURLSessionAPIClient.Configuration(
            baseURL: baseURL,
            apiKey: apiKey,
            minutesBeforeArrivals: 0,
            minutesAfterArrivals: 60
        )
        return OBAURLSessionAPIClient(configuration: config)
    }
}
