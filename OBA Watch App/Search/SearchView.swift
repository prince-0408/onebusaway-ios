//
//  SearchView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

struct SearchView: View {
    @EnvironmentObject private var appState: WatchAppState
    @StateObject private var viewModel: SearchViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: SearchViewModel(
            apiClientProvider: { WatchAppState.shared.apiClient },
            locationProvider: { WatchAppState.shared.currentLocation }
        ))
    }
    
    var body: some View {
        List {
            // Unify the search field so it's always at the top of the single list
            Section {
                TextField(OBALoc("search.placeholder", value: "Search routes, stops...", comment: "Search placeholder"), text: $viewModel.searchText)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.performSearch()
                    }
            }

            if viewModel.searchText.isEmpty {
                if viewModel.recentStops.isEmpty && viewModel.recentSearchTerms.isEmpty {
                    emptySearchStateSections
                } else {
                    recentStopsListSections
                }
            } else {
                searchResultsListSections
            }
        }
        .navigationTitle(OBALoc("common.search", value: "Search", comment: "Search title"))
        .onChange(of: viewModel.searchText) { _, newValue in
            let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                viewModel.performSearch()
            } else {
                viewModel.searchResults = []
                viewModel.bookmarkResults = []
                viewModel.errorMessage = nil
            }
        }
    }

    @ViewBuilder
    private var emptySearchStateSections: some View {
        Section {
            VStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text(OBALoc("search.empty.title", value: "Search for Stops", comment: "Empty state title"))
                    .font(.headline)
                Text(OBALoc("search.empty.subtitle", value: "Enter a stop name or code", comment: "Empty state subtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical)
        }
    }
    
    private var noResultsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text(OBALoc("search.no_results.title", value: "No Results", comment: "No results title"))
                .font(.headline)
            Text(OBALoc("search.no_results.subtitle", value: "Try a different search term", comment: "No results subtitle"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var recentStopsListSections: some View {
        if !viewModel.recentSearchTerms.isEmpty {
            Section(header: Text(OBALoc("search.recent_terms", value: "Recent Searches", comment: "Recent searches header"))) {
                ForEach(viewModel.recentSearchTerms, id: \.self) { term in
                    Button {
                        viewModel.selectRecentSearchTerm(term)
                    } label: {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                            Text(term)
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .foregroundColor(.secondary)
                                .font(.system(size: 10))
                        }
                    }
                }
                
                Button {
                    viewModel.clearRecentSearchTerms()
                } label: {
                    Text(OBALoc("search.clear_recent", value: "Clear Recent", comment: "Clear recent button"))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }

        if !viewModel.recentStops.isEmpty {
            Section(header: Text(OBALoc("search.recent_stops", value: "Recent Stops", comment: "Recent stops header"))) {
                ForEach(viewModel.recentStops) { stop in
                    NavigationLink {
                        LazyView(StopArrivalsView(stopID: stop.id, stopName: stop.name))
                    } label: {
                        SearchResultRow(stop: stop)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchResultsListSections: some View {
        let trimmed = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            Section(OBALoc("search.quick.header", value: "Quick Search", comment: "Quick search header")) {
                QuickSearchButtonsView(query: viewModel.searchText)
            }
        }

        if viewModel.isLoading {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        } else if let error = viewModel.errorMessage {
            Section {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption2)
            }
        } else if !viewModel.bookmarkResults.isEmpty || !viewModel.searchResults.isEmpty {
            if !viewModel.bookmarkResults.isEmpty {
                Section(OBALoc("search.section.bookmarks", value: "Bookmarks", comment: "Bookmarks section header")) {
                    ForEach(viewModel.bookmarkResults) { bm in
                        NavigationLink {
                            LazyView(StopArrivalsView(stopID: bm.stopID, stopName: bm.name))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bm.name)
                                    .font(.headline)
                                    .lineLimit(2)
                                HStack(spacing: 6) {
                                    if let route = bm.routeShortName, !route.isEmpty {
                                        Text(route)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    if let headsign = bm.tripHeadsign, !headsign.isEmpty {
                                        Text(headsign)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if !viewModel.searchResults.isEmpty {
                Section(OBALoc("search.section.stops", value: "Stops", comment: "Stops section header")) {
                    ForEach(viewModel.searchResults) { stop in
                        NavigationLink {
                            LazyView(
                                StopArrivalsView(stopID: stop.id, stopName: stop.name)
                                    .onAppear {
                                        viewModel.recordRecent(stop: stop)
                                    }
                            )
                        } label: {
                            SearchResultRow(stop: stop, currentLocation: appState.currentLocation)
                        }
                    }
                }
            }
        } else if !trimmed.isEmpty {
            Section {
                noResultsState
            }
        }
    }
}

struct SearchResultRow: View {
    let stop: OBAStop
    let currentLocation: CLLocation?

    init(stop: OBAStop, currentLocation: CLLocation? = nil) {
        self.stop = stop
        self.currentLocation = currentLocation
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.red.gradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.headline)
                    .lineLimit(2)
                
                HStack(spacing: 6) {
                    if let code = stop.code {
                        Text(String(format: OBALoc("search.stop_code_fmt", value: "Stop %@", comment: "Stop code format"), code))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let location = currentLocation, stop.latitude != 0.0 || stop.longitude != 0.0 {
                        let stopLoc = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                        let distMeters = stopLoc.distance(from: location)
                        Text("• \(formattedDistance(distMeters))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func formattedDistance(_ distanceMeters: CLLocationDistance) -> String {
        if distanceMeters < 1000 {
            return String(format: "%.0f m", distanceMeters)
        } else {
            return String(format: "%.1f km", distanceMeters / 1000.0)
        }
    }
}

struct QuickSearchButtonsView: View {
    let query: String
    
    @State private var navToRoute = false
    @State private var navToAddress = false
    @State private var navToStop = false
    @State private var navToVehicle = false

    var body: some View {
        VStack(spacing: 3) {
            // Button 1: Route
            Button {
                navToRoute = true
            } label: {
                GlassQuickSearchCardContent(
                    iconName: "bus.fill",
                    iconColor: .green,
                    title: OBALoc("search.quick.route", value: "Route:", comment: "Quick search route"),
                    query: query
                )
            }
            .buttonStyle(.plain)
            .modifier(GlassCapsuleModifier())
            .background(
                NavigationLink(destination: RouteSearchView(initialQuery: query), isActive: $navToRoute) {
                    EmptyView()
                }
                .hidden()
            )

            // Button 2: Address
            Button {
                navToAddress = true
            } label: {
                GlassQuickSearchCardContent(
                    iconName: "mappin.and.ellipse",
                    iconColor: .blue,
                    title: OBALoc("search.quick.address", value: "Address:", comment: "Quick search address"),
                    query: query
                )
            }
            .buttonStyle(.plain)
            .modifier(GlassCapsuleModifier())
            .background(
                NavigationLink(destination: AddressSearchView(initialQuery: query), isActive: $navToAddress) {
                    EmptyView()
                }
                .hidden()
            )

            // Button 3: Stop
            Button {
                navToStop = true
            } label: {
                GlassQuickSearchCardContent(
                    iconName: "tram.fill",
                    iconColor: .orange,
                    title: OBALoc("search.quick.stop", value: "Stop:", comment: "Quick search stop"),
                    query: query
                )
            }
            .buttonStyle(.plain)
            .modifier(GlassCapsuleModifier())
            .background(
                NavigationLink(destination: StopSearchResultsView(initialQuery: query), isActive: $navToStop) {
                    EmptyView()
                }
                .hidden()
            )

            // Button 4: Vehicle
            Button {
                navToVehicle = true
            } label: {
                GlassQuickSearchCardContent(
                    iconName: "car.fill",
                    iconColor: .purple,
                    title: OBALoc("search.quick.vehicle", value: "Vehicle:", comment: "Quick search vehicle"),
                    query: query
                )
            }
            .buttonStyle(.plain)
            .modifier(GlassCapsuleModifier())
            .background(
                NavigationLink(destination: VehicleSearchView(initialQuery: query), isActive: $navToVehicle) {
                    EmptyView()
                }
                .hidden()
            )
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
        .listRowBackground(Color.clear)
    }
}

struct GlassQuickSearchCardContent: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let query: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.22))
                    .frame(width: 26, height: 26)
                
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(iconColor)
            }
            
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                
                Text(query)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Capsule())
    }
}

#Preview {
    SearchView()
}
