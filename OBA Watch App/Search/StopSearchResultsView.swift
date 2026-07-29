import SwiftUI
import CoreLocation
import OBAKitCore

struct StopSearchResultsView: View {
    @EnvironmentObject private var appState: WatchAppState
    @StateObject private var viewModel: StopSearchViewModel

    init(initialQuery: String) {
        _viewModel = StateObject(wrappedValue: StopSearchViewModel(
            initialQuery: initialQuery,
            apiClient: WatchAppState.shared.apiClient,
            locationProvider: { WatchAppState.shared.currentLocation }
        ))
    }

    var body: some View {
        List {
            Section {
                TextField(OBALoc("stop_search.placeholder", value: "Search stops", comment: "Search stops placeholder"), text: $viewModel.query)
                    .onSubmit { viewModel.performSearch() }
                    .onChange(of: viewModel.query) { _, newValue in
                        if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            viewModel.performSearch()
                        } else {
                            viewModel.stops = []
                        }
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
                .listRowBackground(Color.clear)
            } else if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            } else if !viewModel.stops.isEmpty {
                Section {
                    ForEach(viewModel.stops) { stop in
                        NavigationLink {
                            LazyView(StopArrivalsView(stopID: stop.id, stopName: stop.name))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: stop.iconName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.orange.gradient)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(stop.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 6) {
                                        if let code = stop.code {
                                            Text(String(format: OBALoc("stop_search.stop_code_format", value: "Stop %@", comment: "Stop code format"), code))
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }

                                        if let location = appState.currentLocation, stop.latitude != 0.0 || stop.longitude != 0.0 {
                                            let stopLoc = CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                                            let distMeters = stopLoc.distance(from: location)
                                            let distStr = distMeters < 1000 ? String(format: "%.0f m", distMeters) : String(format: "%.1f km", distMeters / 1000.0)
                                            Text("• \(distStr)")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                }
            } else if viewModel.stops.isEmpty && !viewModel.isLoading {
                Section {
                    VStack(spacing: 12) {
                        Spacer(minLength: 20)
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text(OBALoc("stop_search.empty.title", value: "No Stops Found", comment: "No stops found empty state title"))
                            .font(.system(size: 16, weight: .semibold))
                        Text(OBALoc("stop_search.empty.subtitle", value: "Try a different search term.", comment: "No stops found empty state subtitle"))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer(minLength: 20)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle(OBALoc("stop_search.nav_title", value: "Stops", comment: "Stop search navigation title"))
        .onAppear {
            viewModel.performSearch()
        }
    }
}
