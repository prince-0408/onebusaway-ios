import SwiftUI
import CoreLocation
import Combine
import OBAKitCore

struct RouteSearchView: View {
    @StateObject private var viewModel: RouteSearchViewModel

    init(initialQuery: String) {
        _viewModel = StateObject(wrappedValue: RouteSearchViewModel(
            initialQuery: initialQuery,
            apiClient: WatchAppState.shared.apiClient,
            locationProvider: { WatchAppState.shared.currentLocation }
        ))
    }

    var body: some View {
        List {
            Section {
                TextField(OBALoc("route_search.placeholder", value: "Search routes", comment: "Route search placeholder"), text: $viewModel.query)
                    .onSubmit { viewModel.performSearch() }
                    .onChange(of: viewModel.query) { _, newValue in
                        if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            viewModel.performSearch()
                        } else {
                            viewModel.routes = []
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
            } else if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            } else if !viewModel.routes.isEmpty {
                Section(OBALoc("route_search.section.routes", value: "Routes", comment: "Routes section header")) {
                    ForEach(viewModel.routes, id: \.id) { route in
                        NavigationLink {
                            RouteDetailView(route: route)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.green.gradient)
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    if let short = route.shortName, !short.isEmpty {
                                        Text(short)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    if let long = route.longName, !long.isEmpty {
                                        Text(long)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                }
            } else if !viewModel.query.isEmpty && !viewModel.isLoading {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "bus")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text(String(format: OBALoc("route_search.no_match", value: "No Routes Named '%@'", comment: "No routes matching title"), viewModel.query))
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.center)
                        Text(OBALoc("route_search.no_match_subtitle", value: "No bus or rail lines match this search term in your region.", comment: "No routes matching subtitle"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        NavigationLink {
                            AddressSearchView(initialQuery: viewModel.query)
                        } label: {
                            Label(String(format: OBALoc("search.address_for", value: "Search Address '%@'", comment: "Search address shortcut"), viewModel.query), systemImage: "mappin.and.ellipse")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)

                        Button {
                            viewModel.query = ""
                            viewModel.performSearch()
                        } label: {
                            Text(OBALoc("route_search.show_all", value: "Show All Nearby Routes", comment: "Show all routes button"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle(OBALoc("route_search.title", value: "Routes", comment: "Routes title"))
        .onAppear {
            viewModel.performSearch()
        }
    }
}
