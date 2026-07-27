//
//  WalkTimeCalculator.swift
//  OBA Watch App
//

import Foundation
import CoreLocation
import MapKit
import OBAKitCore

struct WalkTimeInfo: Equatable {
    let minutes: Int
    let formattedDistance: String
    let formattedWalkTime: String
    
    /// Straight-line walk estimate matching OBAKit WalkTimeInfo logic.
    static func compute(from userLocation: CLLocation?, to stopLocation: CLLocation?, walkingSpeedMetersPerSecond: Double? = nil) -> WalkTimeInfo? {
        guard let userLocation = userLocation, let stopLocation = stopLocation else { return nil }
        let distance = userLocation.distance(from: stopLocation)
        
        // Suppress when user is right at the stop (<= 30 m)
        guard distance > 30 else { return nil }
        
        let speed: Double
        if let customSpeed = walkingSpeedMetersPerSecond {
            speed = customSpeed
        } else {
            let stored = WatchAppState.userDefaults.double(forKey: "UserDataStore.walkingSpeedMetersPerSecond")
            speed = stored > 0.1 ? stored : 1.35
        }
        
        let seconds = distance / speed
        let minutes = Int(ceil(seconds / 60.0))
        
        let distanceFormatter = MKDistanceFormatter()
        distanceFormatter.units = .default
        let distString = distanceFormatter.string(fromDistance: distance)
        
        let walkFmt = OBALoc("walk_time.format", value: "🚶 %d min (%@)", comment: "Walk time format with minutes and distance")
        let walkString = String(format: walkFmt, minutes, distString)
        
        return WalkTimeInfo(minutes: minutes, formattedDistance: distString, formattedWalkTime: walkString)
    }
}
