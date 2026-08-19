//
//  ClosestDeparturesView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 19/08/26.
//

import SwiftUI
import CoreLocation
import OBAKitCore

/// Displays the closest stop to the rider's current location along with its
/// next upcoming departures directly on the main watch menu.
struct ClosestDeparturesView: View {
    @EnvironmentObject private var appState: WatchAppState
    @StateObject private var viewModel = ClosestDeparturesViewModel()

    @State private var navigateToStop: Bool = false
    @State private var selectedArrival: OBAArrival? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if viewModel.isLoading && viewModel.closestStop == nil {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(OBALoc("closest_departures.finding_closest", value: "Finding closest stop...", comment: "Loading text for closest departures"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            } else if let stop = viewModel.closestStop {
                VStack(alignment: .leading, spacing: 6) {
                    // Header: Button to open full Stop Arrival Page
                    Button {
                        navigateToStop = true
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.brand)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stop.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                let cleanStopID = stop.id.replacingOccurrences(of: "^[^_]+_", with: "", options: .regularExpression)
                                Text(String(format: OBALoc("stop_arrivals.stop_id_fmt", value: "Stop #%@", comment: "Stop ID format"), cleanStopID))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer(minLength: 2)
                            
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .navigationDestination(isPresented: $navigateToStop) {
                        StopArrivalsView(stopID: stop.id, stopName: stop.name)
                    }

                    // Walk distance / time indicator if available
                    let userLoc = appState.effectiveLocation
                    let stopLoc = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                    if let walkInfo = WalkTimeInfo.compute(from: userLoc, to: stopLoc) {
                        HStack(spacing: 3) {
                            Image(systemName: "figure.walk")
                                .font(.system(size: 9))
                            Text(walkInfo.formattedWalkTime)
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundColor(.brand)
                    }

                    Divider()
                        .background(Color.white.opacity(0.15))

                    // Next Departures List (up to 3 arrivals)
                    if viewModel.isArrivalsLoading && viewModel.upcomingArrivals.isEmpty {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(OBALoc("closest_departures.loading_arrivals", value: "Loading departures...", comment: "Loading text for arrivals"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    } else if viewModel.upcomingArrivals.isEmpty {
                        Text(OBALoc("stop_arrivals.no_upcoming_arrivals", value: "No Upcoming Arrivals", comment: "No upcoming arrivals text"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 2)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(viewModel.topArrivals, id: \.id) { arrival in
                                Button {
                                    selectedArrival = arrival
                                } label: {
                                    HStack(spacing: 6) {
                                        // Route Badge
                                        Text(arrival.routeShortName ?? "??")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.brand.gradient)
                                            .cornerRadius(6)

                                        // Headsign
                                        Text(arrival.headsign ?? OBALoc("common.unknown", value: "Unknown", comment: "Unknown headsign"))
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Spacer(minLength: 2)

                                        // Countdown Time
                                        Text(arrival.timeString)
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(arrival.minutesFromNow <= 2 ? .green : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .navigationDestination(isPresented: Binding(
                            get: { selectedArrival != nil },
                            set: { if !$0 { selectedArrival = nil } }
                        )) {
                            if let arrival = selectedArrival {
                                ArrivalDetailView(arrival: arrival)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "location.slash")
                        .foregroundColor(.secondary)
                    Text(OBALoc("nearby_stops.no_stops", value: "No Stops Found Nearby", comment: "No nearby stops text"))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadClosestStopAndArrivals()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .LocationUpdated)) { _ in
            Task {
                await viewModel.loadClosestStopAndArrivals()
            }
        }
    }
}
