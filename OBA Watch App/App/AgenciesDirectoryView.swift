//
//  AgenciesDirectoryView.swift
//  OBA Watch App
//

import SwiftUI
import CoreLocation
import MapKit
import OBAKitCore

struct AgenciesDirectoryView: View {
    @EnvironmentObject private var appState: WatchAppState
    @State private var agencies: [OBAAgencyCoverage] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 8)
                        Spacer()
                    }
                }
            } else if let error = errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(OBALoc("agencies.error.title", value: "Failed to Load", comment: "Error loading agencies"))
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else if agencies.isEmpty {
                Section {
                    Text(OBALoc("agencies.empty", value: "No agencies found for this region.", comment: "Empty agencies list"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Section(header: Text(OBALoc("agencies.header", value: "Participating Agencies", comment: "Agencies section header"))) {
                    ForEach(agencies) { agency in
                        NavigationLink {
                            AgencyDetailView(agency: agency)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "building.2.crop.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(agency.agencyID)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(String(format: OBALoc("agencies.center_fmt", value: "Lat %.2f, Lon %.2f", comment: "Agency coordinates format"), agency.centerLatitude, agency.centerLongitude))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationTitle(OBALoc("agencies.title", value: "Agencies", comment: "Agencies screen title"))
        .task {
            await loadAgencies()
        }
    }

    private func loadAgencies() async {
        isLoading = true
        do {
            let fetched = try await appState.apiClient.fetchAgenciesWithCoverage()
            self.agencies = fetched.sorted { $0.agencyID < $1.agencyID }
        } catch {
            Logger.error("Failed to fetch agencies: \(error)")
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct AgencyDetailView: View {
    let agency: OBAAgencyCoverage
    @EnvironmentObject private var appState: WatchAppState

    var body: some View {
        List {
            Section(header: Text(agency.agencyID)) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Agency Coverage", systemImage: "mappin.and.ellipse")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Center Location:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("\(agency.centerLatitude), \(agency.centerLongitude)")
                        .font(.caption)
                        .bold()
                }
                .padding(.vertical, 4)
            }

            Section {
                NavigationLink {
                    WatchInteractiveMapView(
                        initialRegion: MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: agency.centerLatitude, longitude: agency.centerLongitude),
                            latitudinalMeters: 5000,
                            longitudinalMeters: 5000
                        )
                    )
                } label: {
                    Label(OBALoc("agencies.view_map", value: "View Region Map", comment: "View agency map button"), systemImage: "map.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle(agency.agencyID)
    }
}
