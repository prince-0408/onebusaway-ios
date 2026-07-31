//
//  BookmarksView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

struct BookmarksView: View {
    @EnvironmentObject private var appState: WatchAppState
    @StateObject private var viewModel: BookmarksViewModel
    
    init() {
        _viewModel = StateObject(wrappedValue: BookmarksViewModel())
    }
    
    var body: some View {
        Group {
            if viewModel.bookmarks.isEmpty {
                emptyStateView
            } else {
                bookmarksList
            }
        }
        .navigationTitle(OBALoc("common.bookmarks", value: "Bookmarks", comment: "Title for the Bookmarks screen"))
        .onAppear {
            viewModel.isViewActive = true
            // Single load point — avoid double-loading from .task + .onAppear
            viewModel.currentLocation = appState.currentLocation
            viewModel.loadBookmarks()
        }
        .onDisappear {
            viewModel.isViewActive = false
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "bookmark")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text(OBALoc("bookmarks.no_bookmarks", value: "No Bookmarks", comment: "Empty state title for bookmarks"))
                .font(.headline)
            Text(OBALoc("bookmarks.add_in_ios_app", value: "Add bookmarks in the iOS app", comment: "Empty state description for bookmarks"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                appState.requestSyncFromPhone()
                viewModel.loadBookmarks()
            } label: {
                Label("Sync from iPhone", systemImage: "arrow.clockwise")
                    .font(.caption2)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
    }
    
    private var bookmarksList: some View {
        List {
            // Search Input Section - Single Layer Native Watch Field
            Section {
                TextField(OBALoc("common.search", value: "Search", comment: "Search input placeholder"), text: $viewModel.searchText)
            }

            // Sort & Sync Controls Section
            Section {
                VStack(spacing: 6) {
                    // Sort Mode Segmented Switcher
                    HStack(spacing: 4) {
                        ForEach(BookmarkSortOption.allCases) { mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.sortOption = mode
                                }
                            } label: {
                                Text(mode.rawValue)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(viewModel.sortOption == mode ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(viewModel.sortOption == mode ? Color.brand : Color.white.opacity(0.12))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Sync Status Line
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundColor(.brand)
                            Text(syncStatusText)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            viewModel.forceSyncWithPhone()
                        } label: {
                            Text(OBALoc("common.sync", value: "Sync", comment: "Sync button"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.brand)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 4, trailing: 0))

            // Bookmarks Sections
            ForEach(viewModel.filteredGroupedBookmarks) { group in
                if viewModel.filteredGroupedBookmarks.count > 1 || group.name != OBALoc("common.bookmarks", value: "Bookmarks", comment: "Default bookmarks group name") {
                    Section(header: HStack {
                        Label(group.name, systemImage: "folder.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.brand)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.gray.opacity(0.2)))
                    }) {
                        groupRows(group.items)
                    }
                } else {
                    Section {
                        groupRows(group.items)
                    }
                }
            }
        }
    }
    
    private var syncStatusText: String {
        if let date = viewModel.lastSyncedDate {
            let elapsed = Int(Date().timeIntervalSince(date))
            if elapsed < 10 {
                return OBALoc("bookmarks.synced_just_now", value: "Synced just now", comment: "Synced just now label")
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return String(format: OBALoc("bookmarks.synced_fmt", value: "Synced %@", comment: "Synced time label"), formatter.localizedString(for: date, relativeTo: Date()))
        }
        return OBALoc("bookmarks.synced", value: "Synced", comment: "Synced label")
    }

    @ViewBuilder
    private func groupRows(_ items: [WatchBookmark]) -> some View {
        ForEach(items) { bookmark in
            NavigationLink {
                StopArrivalsView(stopID: bookmark.stopID, stopName: bookmark.name)
            } label: {
                BookmarkRow(bookmark: bookmark)
            }
        }
        .onDelete { indexSet in
            viewModel.deleteBookmarks(at: indexSet, from: items)
        }
    }
}

struct BookmarkRow: View {
    let bookmark: WatchBookmark
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.brand.gradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.name)
                    .font(.headline)
                    .lineLimit(1)
                
                if let routeName = bookmark.routeShortName {
                    HStack(spacing: 4) {
                        Text(String(format: OBALoc("common.route_fmt", value: "Route %@", comment: "Route name format"), routeName))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let headsign = bookmark.tripHeadsign {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text(headsign)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else if let stopObj = bookmark.stop {
                    Text(stopObj.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

#Preview {
    BookmarksView()
}
