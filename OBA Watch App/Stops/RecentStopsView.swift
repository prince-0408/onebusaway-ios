//
//  RecentStopsView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore
struct RecentStopsView: View {
    @ObservedObject private var viewModel = RecentStopsViewModel.shared
    @State private var showClearConfirmation = false
    
    var body: some View {
        Group {
            if viewModel.recentStops.isEmpty {
                emptyStateView
            } else {
                recentStopsList
            }
        }
        .navigationTitle(OBALoc("recent_stops.title", value: "Recent Stops", comment: "Title for recent stops screen"))
        .toolbar {
            if !viewModel.recentStops.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .confirmationDialog(
            OBALoc("recent_stops.clear_title", value: "Clear Recent Stops?", comment: "Clear recent stops title"),
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(OBALoc("recent_stops.clear_confirm", value: "Clear All", comment: "Clear all button"), role: .destructive) {
                viewModel.clearAllRecentStops()
                WatchFeedbackGenerator.shared.success()
            }
            Button(OBALoc("common.cancel", value: "Cancel", comment: "Cancel button"), role: .cancel) { }
        }
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "clock",
            title: OBALoc("recent_stops.no_recent_stops", value: "No Recent Stops", comment: "Empty state title for recent stops"),
            message: OBALoc("recent_stops.view_stops_instruction", value: "View stops to see them here", comment: "Instruction for recent stops")
        )
    }
    
    private var recentStopsList: some View {
        List {
            Section {
                ForEach(viewModel.recentStops) { stop in
                    NavigationLink {
                        LazyView(StopArrivalsView(stopID: stop.id, stopName: stop.name))
                    } label: {
                        RecentStopRow(stop: stop)
                    }
                }
                .onDelete { indexSet in
                    viewModel.removeRecentStop(at: indexSet)
                }
            }
        }
        .listStyle(.carousel)
    }
}

struct RecentStopRow: View {
    let stop: OBAStop
    
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 30, height: 30)
                
                Image(systemName: "bus.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(stop.name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    
                    if let dir = stop.direction, !dir.isEmpty {
                        Text(dir)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.secondary.opacity(0.5)))
                    }
                }
                
                if let routes = stop.routeNames, !routes.isEmpty {
                    Text(routes)
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                if let code = stop.code, !code.isEmpty {
                    Text(String(format: OBALoc("recent_stops.stop_code_fmt", value: "Stop %@", comment: "Stop code format"), code))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

#Preview {
    RecentStopsView()
}
