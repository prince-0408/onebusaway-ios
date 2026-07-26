//
//  StopPreferencesStore.swift
//  OBA Watch App
//

import Foundation
import Combine
import OBAKitCore

@MainActor
class StopPreferencesStore: ObservableObject {
    static let shared = StopPreferencesStore()
    
    @Published private var preferencesByStopID: [OBAStopID: StopPreferences] = [:]
    
    private let userDefaultsKey = "store.stop_preferences"
    
    init() {
        loadFromUserDefaults()
    }
    
    func preferences(for stopID: OBAStopID) -> StopPreferences {
        preferencesByStopID[stopID] ?? StopPreferences()
    }
    
    func isRouteHidden(stopID: OBAStopID, routeID: String) -> Bool {
        let prefs = preferences(for: stopID)
        return prefs.isRouteIDHidden(routeID)
    }
    
    func toggleRouteHidden(stopID: OBAStopID, routeID: String) {
        var prefs = preferences(for: stopID)
        prefs.toggleRouteIDHidden(routeID)
        preferencesByStopID[stopID] = prefs
        saveToUserDefaults()
    }
    
    func setSortType(stopID: OBAStopID, sortType: StopSort) {
        var prefs = preferences(for: stopID)
        prefs.sortType = sortType
        preferencesByStopID[stopID] = prefs
        saveToUserDefaults()
    }
    
    func unhideAllRoutes(stopID: OBAStopID) {
        var prefs = preferences(for: stopID)
        prefs.hiddenRoutes.removeAll()
        preferencesByStopID[stopID] = prefs
        saveToUserDefaults()
    }
    
    private func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([OBAStopID: StopPreferences].self, from: data) else {
            return
        }
        preferencesByStopID = decoded
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(preferencesByStopID) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
