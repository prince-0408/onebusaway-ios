//
//  VehiclePolylineGlider.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import CoreLocation
import SwiftUI

/// High-precision dead-reckoning polyline glider for watchOS.
/// Smoothly interpolates vehicle position along actual road polyline coordinates
/// between 10-second server polling intervals.
@MainActor
final class VehiclePolylineGlider: ObservableObject {

    @Published var currentCoordinate: CLLocationCoordinate2D?
    @Published var currentHeading: Double = 0.0
    @Published var currentSegmentIndex: Int = 0

    private var polyline: [CLLocationCoordinate2D] = []
    private var targetIndex: Int = 0
    private var progress: Double = 0.0
    private var glideTimer: Timer?
    private var speedMetersPerSecond: Double = 8.0 // Default ~28 km/h transit speed

    func updatePolyline(_ newPolyline: [CLLocationCoordinate2D]) {
        guard !newPolyline.isEmpty else { return }
        self.polyline = newPolyline
        if currentCoordinate == nil {
            self.currentCoordinate = newPolyline.first
            self.currentSegmentIndex = 0
            self.progress = 0.0
        }
    }

    func setTargetLocation(_ target: CLLocationCoordinate2D) {
        guard !polyline.isEmpty else {
            withAnimation(.easeInOut(duration: 2.0)) {
                self.currentCoordinate = target
            }
            return
        }

        // Find nearest index on polyline to target location
        let closestIdx = findNearestPolylineIndex(to: target)
        self.targetIndex = closestIdx

        if currentCoordinate == nil {
            self.currentCoordinate = polyline[closestIdx]
            self.currentSegmentIndex = closestIdx
            self.progress = 0.0
        }

        startGliding()
    }

    func startGliding() {
        guard glideTimer == nil else { return }
        glideTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickGlider()
            }
        }
    }

    func stopGliding() {
        glideTimer?.invalidate()
        glideTimer = nil
    }

    private func tickGlider() {
        guard polyline.count > 1 else { return }
        
        // If current index reached target index and progress is 1.0, stop
        if currentSegmentIndex >= targetIndex && currentSegmentIndex >= polyline.count - 1 {
            return
        }
        
        let p1 = polyline[currentSegmentIndex]
        let p2Idx = min(currentSegmentIndex + 1, polyline.count - 1)
        let p2 = polyline[p2Idx]

        let dist = haversine(p1, p2)
        let step = (speedMetersPerSecond * 0.25) / max(dist, 1.0)
        
        progress += step

        if progress >= 1.0 {
            progress = 0.0
            if currentSegmentIndex < targetIndex && currentSegmentIndex < polyline.count - 1 {
                currentSegmentIndex += 1
            }
        }

        let currP1 = polyline[currentSegmentIndex]
        let currP2Idx = min(currentSegmentIndex + 1, polyline.count - 1)
        let currP2 = polyline[currP2Idx]

        // Calculate heading tangent along the road segment
        let heading = calculateBearing(from: currP1, to: currP2)
        
        // Interpolate coordinate
        let lerpLat = currP1.latitude + (currP2.latitude - currP1.latitude) * progress
        let lerpLon = currP1.longitude + (currP2.longitude - currP1.longitude) * progress
        let glidedCoord = CLLocationCoordinate2D(latitude: lerpLat, longitude: lerpLon)

        withAnimation(.linear(duration: 0.25)) {
            self.currentCoordinate = glidedCoord
            self.currentHeading = heading
        }
    }

    var passedPolyline: [CLLocationCoordinate2D] {
        guard !polyline.isEmpty else { return [] }
        var result = Array(polyline[0...min(currentSegmentIndex, polyline.count - 1)])
        if let current = currentCoordinate {
            result.append(current)
        }
        return result
    }

    var upcomingPolyline: [CLLocationCoordinate2D] {
        guard !polyline.isEmpty else { return [] }
        var result: [CLLocationCoordinate2D] = []
        if let current = currentCoordinate {
            result.append(current)
        }
        let nextIdx = min(currentSegmentIndex + 1, polyline.count - 1)
        if nextIdx < polyline.count {
            result.append(contentsOf: polyline[nextIdx..<polyline.count])
        }
        return result
    }

    private func findNearestPolylineIndex(to target: CLLocationCoordinate2D) -> Int {
        var minDistance: Double = .greatestFiniteMagnitude
        var closest = 0
        for (idx, coord) in polyline.enumerated() {
            let dist = haversine(target, coord)
            if dist < minDistance {
                minDistance = dist
                closest = idx
            }
        }
        return closest
    }

    private func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let phi1 = a.latitude * .pi / 180
        let phi2 = b.latitude * .pi / 180
        let dphi = (b.latitude - a.latitude) * .pi / 180
        let dl = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dphi/2)*sin(dphi/2) + cos(phi1)*cos(phi2)*sin(dl/2)*sin(dl/2)
        return 2 * R * asin(sqrt(h))
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        return radians * 180 / .pi
    }
}
