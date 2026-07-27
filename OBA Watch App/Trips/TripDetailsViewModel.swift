//
//  TripDetailsViewModel.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import Foundation
import SwiftUI
import Combine
import OBAKitCore

import CoreLocation
import MapKit

@MainActor
class TripDetailsViewModel: ObservableObject {
    @Published var tripDetails: OBATripExtendedDetails?
    @Published var polyline: [CLLocationCoordinate2D] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var vehicleLatitude: Double?
    @Published var vehicleLongitude: Double?
    
    private var trackingTask: Task<Void, Never>?
    
    var vehicleCoordinate: CLLocationCoordinate2D? {
        if let lat = vehicleLatitude, let lon = vehicleLongitude, lat != 0.0, lon != 0.0 {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        if let pos = tripDetails?.status?.position, pos.lat != 0.0, pos.lon != 0.0 {
            return CLLocationCoordinate2D(latitude: pos.lat, longitude: pos.lon)
        }
        if let lat = initialTrip?.latitude, let lon = initialTrip?.longitude, lat != 0.0, lon != 0.0 {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    var vehicleDistanceAlongTrip: Double? {
        if let stopTimes = tripDetails?.schedule?.stopTimes, !stopTimes.isEmpty {
            // 1. If status reports the upcoming stop ID, use that stop's distance
            if let nextStopID = tripDetails?.status?.nextStop, !nextStopID.isEmpty {
                if let match = stopTimes.first(where: { $0.stopId == nextStopID }),
                   let d = match.distanceAlongTrip, d > 0 {
                    return d
                }
            }
            // 2. Otherwise if status reports closestStop, use that as a fallback
            if let closestStopID = tripDetails?.status?.closestStop, !closestStopID.isEmpty {
                if let match = stopTimes.first(where: { $0.stopId == closestStopID }),
                   let d = match.distanceAlongTrip, d > 0 {
                    return d
                }
            }
            // 3. Final fallback: find the stop geographically nearest the vehicle lat/lon
            if let vehicle = vehicleCoordinate {
                var nearestDist: Double = .greatestFiniteMagnitude
                var nearestStopDistance: Double = 0
                for st in stopTimes {
                    guard let lat = st.latitude, let lon = st.longitude else { continue }
                    let d = haversine(vehicle, CLLocationCoordinate2D(latitude: lat, longitude: lon))
                    if d < nearestDist {
                        nearestDist = d
                        nearestStopDistance = st.distanceAlongTrip ?? 0
                    }
                }
                if nearestStopDistance > 0 { return nearestStopDistance }
            }
        }
        return nil
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
    
    private let apiClient: OBAAPIClient
    private var tripID: String
    private let vehicleID: String?
    private let initialTrip: OBATripForLocation?
    
    init(apiClient: OBAAPIClient, tripID: String, vehicleID: String? = nil, initialTrip: OBATripForLocation? = nil) {
        self.apiClient = apiClient
        self.tripID = tripID
        self.vehicleID = vehicleID
        self.initialTrip = initialTrip
        
        // If we have an initial trip, use its status immediately
        if let trip = initialTrip {
            self.tripDetails = OBATripExtendedDetails(
                tripId: trip.id,
                serviceDate: nil,
                frequency: nil,
                status: trip.toStatus,
                schedule: nil
            )
        }
    }
    
    func loadDetails() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            var tripIDToFetch = tripID
            
            // If tripID is missing but we have a vehicleID, try to find the current trip for that vehicle
            if tripIDToFetch.isEmpty, let vID = vehicleID, !vID.isEmpty {
                do {
                    let vehicle = try await apiClient.fetchVehicle(vehicleID: vID)
                    if let tID = vehicle.tripID, !tID.isEmpty {
                        tripIDToFetch = tID
                        self.tripID = tID
                    } else {
                        errorMessage = String(format: OBALoc("trip_details.error.vehicle_not_on_trip_fmt", value: "Vehicle %@ is not currently on an active trip.", comment: "Vehicle not on active trip"), vID)
                        return
                    }
                } catch {
                    errorMessage = String(format: OBALoc("trip_details.error.unable_find_trip_fmt", value: "Unable to find trip for vehicle %@.", comment: "Unable to find trip for vehicle"), vID)
                    return
                }
            }
            
            if tripIDToFetch.isEmpty {
                errorMessage = OBALoc("trip_details.error.no_trip_info", value: "No trip information available.", comment: "No trip info available")
                return
            }

            // Fetch trip details for schedule/stops
            let details = try await apiClient.fetchTripDetails(tripID: tripIDToFetch)
            
            // Preserve status if the new details don't have it but we have one
            var finalStatus = details.status ?? self.tripDetails?.status
            
            // If status is still missing from trip details, but we have a vehicleID, try to fetch it
            if finalStatus == nil, let vID = vehicleID, !vID.isEmpty {
                do {
                    let vehicleStatus = try await apiClient.fetchTripForVehicle(vehicleID: vID)
                    finalStatus = vehicleStatus.status
                } catch {
                    Logger.error("fetchTripForVehicle failed for \(vID): \(error)")
                }
            }
            
            self.tripDetails = OBATripExtendedDetails(
                tripId: details.tripId,
                serviceDate: details.serviceDate,
                frequency: details.frequency,
                status: finalStatus,
                schedule: details.schedule
            )
            
            // If status position is directly available in trip details, populate vehicle coordinates immediately
            if let pos = finalStatus?.position, pos.lat != 0.0, pos.lon != 0.0 {
                self.vehicleLatitude = pos.lat
                self.vehicleLongitude = pos.lon
            }
            
            // Fetch trip info for shapeID
            let tripInfo = try await apiClient.fetchTrip(tripID: tripIDToFetch)
            if let shapeID = tripInfo.shapeID {
                let encodedPolyline = try await apiClient.fetchShape(shapeID: shapeID)
                self.polyline = OBAURLSessionAPIClient.decodePolyline(encodedPolyline)
            } else if let stopTimes = details.schedule?.stopTimes {
                // Fallback: if no shape, use stop coordinates as a basic line
                self.polyline = stopTimes.compactMap { stopTime -> CLLocationCoordinate2D? in
                    guard let lat = stopTime.latitude, let lon = stopTime.longitude else { return nil }
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }

            await resolveLiveVehiclePosition(tripIDToFetch: tripIDToFetch)
            startLiveTrackingLoop(tripIDToFetch: tripIDToFetch)
        } catch {
            errorMessage = error.watchOSUserFacingMessage
        }
    }

    func stopLiveTracking() {
        trackingTask?.cancel()
        trackingTask = nil
    }

    private func startLiveTrackingLoop(tripIDToFetch: String) {
        trackingTask?.cancel()
        trackingTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds live poll
                if Task.isCancelled { break }
                await self.resolveLiveVehiclePosition(tripIDToFetch: tripIDToFetch)
            }
        }
    }

    private func resolveLiveVehiclePosition(tripIDToFetch: String) async {
        let activeVehicleID = self.vehicleID ?? tripDetails?.status?.vehicleID
        
        if let vID = activeVehicleID, !vID.isEmpty {
            do {
                let vehicleStatus = try await apiClient.fetchTripForVehicle(vehicleID: vID)
                if let pos = vehicleStatus.status?.position, pos.lat != 0.0, pos.lon != 0.0 {
                    self.vehicleLatitude = pos.lat
                    self.vehicleLongitude = pos.lon
                    if let updatedStatus = vehicleStatus.status {
                        self.tripDetails = OBATripExtendedDetails(
                            tripId: self.tripDetails?.tripId ?? tripIDToFetch,
                            serviceDate: self.tripDetails?.serviceDate,
                            frequency: self.tripDetails?.frequency,
                            status: updatedStatus,
                            schedule: self.tripDetails?.schedule
                        )
                    }
                    return
                }
            } catch {
                Logger.error("fetchTripForVehicle failed for \(vID): \(error)")
            }
        }

        if let pos = tripDetails?.status?.position, pos.lat != 0.0, pos.lon != 0.0 {
            self.vehicleLatitude = pos.lat
            self.vehicleLongitude = pos.lon
            return
        }

        // Query nearby vehicles along polyline or schedule center
        if let center = polyline.first ?? (tripDetails?.schedule?.stopTimes.first.flatMap { st in
            if let lat = st.latitude, let lon = st.longitude { return CLLocationCoordinate2D(latitude: lat, longitude: lon) }
            return nil
        }) {
            do {
                let nearby = try await apiClient.fetchVehiclesReliably(latitude: center.latitude, longitude: center.longitude, latSpan: 0.1, lonSpan: 0.1)
                if let match = nearby.first(where: { $0.id == tripIDToFetch || (activeVehicleID != nil && $0.vehicleID == activeVehicleID) }),
                   let lat = match.latitude, let lon = match.longitude, lat != 0.0, lon != 0.0 {
                    self.vehicleLatitude = lat
                    self.vehicleLongitude = lon
                }
            } catch {
                Logger.error("Failed to query nearby vehicles: \(error)")
            }
        }
    }
}
