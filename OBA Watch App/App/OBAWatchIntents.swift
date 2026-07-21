//
//  OBAWatchIntents.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import AppIntents
import SwiftUI
import OBAKitCore

/// AppIntent for Apple Watch Ultra Action Button & Siri Voice Shortcuts.
/// Allows riders to quickly refresh arrival times or check transit status.
struct RefreshArrivalsIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "Refresh Transit Arrivals"
    nonisolated static let description: IntentDescription = IntentDescription("Refreshes real-time bus arrivals for your primary bookmarked stop.")
    nonisolated static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Trigger a region/arrivals refresh notification
        NotificationCenter.default.post(name: .LocationUpdated, object: nil)
        return .result()
    }
}
