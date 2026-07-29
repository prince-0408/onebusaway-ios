//
//  Application+WatchSync.swift
//  OBAKit
//
//  Copyright © Open Transit Software Foundation
//  This source code is licensed under the Apache 2.0 license found in the
//  LICENSE file in the root directory of this source tree.
//

import Foundation
import WatchConnectivity
import OBAKitCore

// MARK: - WCSessionDelegate
extension Application {
    public nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("[iOS Debug] WCSession activationDidCompleteWith state=\(activationState.rawValue), error=\(String(describing: error))")
        if let error = error {
            Logger.error("WCSession activation failed: \(error)")
            return
        }

        Task { @MainActor in
            if activationState == .activated {
                print("[iOS Debug] WCSession activated, calling sendAllDataToWatch()")
                self.sendAllDataToWatch()
            }
        }
    }

    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // nop
    }

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate the session
        WCSession.default.activate()
    }

    public nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("[iOS Debug] Received message from Watch: \(message)")
        
        var bookmarksData: Data? = nil
        if let bookmarksArray = message["bookmarks"] as? [[String: Any]] {
            bookmarksData = try? JSONSerialization.data(withJSONObject: bookmarksArray, options: [])
        }
        
        Task { @MainActor in
            if let bookmarksData = bookmarksData {
                self.syncBookmarksFromWatchData(bookmarksData)
            } else {
                self.sendAllDataToWatch()
            }
        }
    }
}

extension Application {
    // MARK: - Watch Sync

    private func syncBookmarksFromWatchData(_ jsonData: Data) {
        guard let decoded = try? JSONDecoder().decode([WatchBookmark].self, from: jsonData) else {
            print("[iOS Debug] syncBookmarksFromWatchData: Failed to decode watch bookmarks")
            return
        }
        
        print("[iOS Debug] syncBookmarksFromWatchData: Received \(decoded.count) bookmarks from watch")
        
        let currentBookmarks = userDataStore.bookmarks
        let currentRegionID = regionsService.currentRegion?.regionIdentifier ?? 0
        
        NotificationCenter.default.removeObserver(self, name: .OBABookmarksUpdated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .bookmarksDidChange, object: nil)
        
        defer {
            NotificationCenter.default.addObserver(self, selector: #selector(bookmarksUpdated(_:)), name: .OBABookmarksUpdated, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(bookmarksUpdated(_:)), name: .bookmarksDidChange, object: nil)
            self.sendAllDataToWatch()
        }
        
        // Delete bookmarks present on phone but missing in watch list
        for existing in currentBookmarks {
            let isStillPresent = decoded.contains { bm in
                bm.stopID == existing.stopID && bm.routeShortName == existing.routeShortName
            }
            if !isStillPresent {
                print("[iOS Debug] syncBookmarksFromWatch: Deleting bookmark \(existing.name) for stop \(existing.stopID)")
                userDataStore.delete(bookmark: existing)
            }
        }
        
        // Add new bookmarks present in watch list but missing on phone
        for bm in decoded {
            let existsOnPhone = currentBookmarks.contains { existing in
                existing.stopID == bm.stopID && existing.routeShortName == bm.routeShortName
            }
            if !existsOnPhone {
                print("[iOS Debug] syncBookmarksFromWatch: Adding new bookmark \(bm.name) for stop \(bm.stopID)")
                
                let lat = bm.stop?.latitude ?? 0.0
                let lon = bm.stop?.longitude ?? 0.0
                let code = bm.stop?.code ?? ""
                let direction = bm.stop?.direction ?? ""
                let locationType = bm.stop?.locationType ?? 0
                
                let stopDict: [String: Any] = [
                    "id": bm.stopID,
                    "name": bm.name,
                    "lat": lat,
                    "lon": lon,
                    "code": code,
                    "direction": direction,
                    "locationType": locationType,
                    "routeIds": []
                ]
                
                guard let stopData = try? JSONSerialization.data(withJSONObject: stopDict),
                      let stop = try? JSONDecoder().decode(Stop.self, from: stopData) else {
                    print("[iOS Debug] syncBookmarksFromWatch: Failed to decode Stop object for \(bm.name)")
                    continue
                }
                
                let regionID: Int
                if let firstPart = bm.stopID.split(separator: "_").first,
                   let parsedRegion = Int(firstPart) {
                    regionID = parsedRegion
                } else {
                    regionID = currentRegionID
                }
                
                let bookmark = Bookmark(
                    name: bm.name,
                    regionIdentifier: regionID,
                    arrivalDeparture: nil,
                    stop: stop
                )
                
                var group: BookmarkGroup? = nil
                if let groupName = bm.groupName, !groupName.isEmpty {
                    group = userDataStore.bookmarkGroups.first { $0.name == groupName }
                }
                
                userDataStore.add(bookmark, to: group)
            }
        }
    }

    @objc func bookmarksUpdated(_ notification: Notification) {
        print("[iOS Debug] bookmarksUpdated notification received")
        sendBookmarksToWatch()
    }

    @objc func alarmsUpdated(_ notification: Notification) {
        sendAlarmsToWatch()
    }

    @objc func serviceAlertsUpdated(_ notification: Notification) {
        sendServiceAlertsToWatch()
    }

    @objc func regionsUpdated(_ notification: Notification) {
        sendAllDataToWatch()
    }

    func sendBookmarksToWatch() {
        sendAllDataToWatch()
    }

    func sendAlarmsToWatch() {
        sendAllDataToWatch()
    }

    func sendServiceAlertsToWatch() {
        sendAllDataToWatch()
    }

    func sendAllDataToWatch() {
        let bookmarkData = buildBookmarkData()
        let alarmData = buildAlarmData()
        let alertData = buildAlertData()
        let regionData = buildRegionData()

        print("[iOS Debug] sendAllDataToWatch: bookmarks count=\(userDataStore.bookmarks.count), built bookmarkData count=\(bookmarkData?.count ?? 0)")

        guard let session = watchSession, session.activationState == .activated else {
            pendingWatchSync = true
            Logger.info("Watch sync queued for WCSession activation. Shared App Group container updated.")
            print("[iOS Debug] watchSession not active. Queued pendingWatchSync. watchSession=\(String(describing: watchSession))")
            return
        }

        var context: [String: Any] = [:]
        context["bookmarks"] = bookmarkData ?? []
        context["alarms"] = alarmData ?? []
        context["alerts"] = alertData ?? []
        context["regions"] = regionData ?? []

        do {
            try session.updateApplicationContext(context)
            session.transferUserInfo(context)
            if session.isReachable {
                session.sendMessage(context, replyHandler: nil) { err in
                    print("[iOS Debug] sendMessage error: \(err.localizedDescription)")
                }
            }
            pendingWatchSync = false
            print("[iOS Debug] Watch sync sent successfully via updateApplicationContext & transferUserInfo. Reachable=\(session.isReachable)")
        } catch {
            Logger.error("Watch sync failed: \(error)")
            print("[iOS Debug] updateApplicationContext error: \(error). Falling back to transferUserInfo.")
            session.transferUserInfo(context)
        }
    }

    private func buildRegionData() -> [Data]? {
        let regions = regionsService.regions
        guard !regions.isEmpty else { return nil }

        return regions.compactMap { region -> Data? in
            let coordinate = region.centerCoordinate
            
            struct SimpleRegion: Encodable {
                let id: String
                let name: String
                let latitude: Double
                let longitude: Double
                let obaBaseURL: URL?
                let otpBaseURL: URL?
            }
            
            let simple = SimpleRegion(
                id: String(region.regionIdentifier),
                name: region.name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                obaBaseURL: region.OBABaseURL,
                otpBaseURL: region.openTripPlannerURL
            )
            
            return try? JSONEncoder().encode(simple)
        }
    }

    private func buildWatchData<T: Encodable>(items: [T], defaultsKey: String, logName: String) -> [[String: Any]]? {
        guard !items.isEmpty else {
            userDefaults.removeObject(forKey: defaultsKey)
            return nil
        }

        // Write to shared container (App Group) if possible
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: defaultsKey)
        } catch {
            Logger.error("Failed to encode watch \(logName): \(error)")
        }

        return items.compactMap { item -> [String: Any]? in
            do {
                let data = try JSONEncoder().encode(item)
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                Logger.error("Failed to encode individual watch \(logName) item: \(error)")
                return nil
            }
        }
    }

    private func buildBookmarkData() -> [[String: Any]]? {
        let groups = Dictionary(uniqueKeysWithValues: userDataStore.bookmarkGroups.map { ($0.id, $0.name) })
        let watchBookmarks = userDataStore.bookmarks.map { bm -> WatchBookmark in
            let groupName = bm.groupID.flatMap { groups[$0] }
            return bm.buildWatchBookmarkObject(groupName: groupName)
        }
        return buildWatchData(items: watchBookmarks, defaultsKey: "watch.bookmarks", logName: "bookmarks")
    }

    private func buildAlarmData() -> [[String: Any]]? {
        buildWatchData(items: userDataStore.alarms.map { $0.watchAlarmItem }, defaultsKey: "watch.alarms", logName: "alarms")
    }

    private func buildAlertData() -> [[String: Any]]? {
        buildWatchData(items: alertsStore.agencyAlerts.map { $0.watchServiceAlert }, defaultsKey: "watch.service_alerts", logName: "service alerts")
    }
}
