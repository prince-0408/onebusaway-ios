//
//  NearbyStopsContainerView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI

/// A shared container view for displaying nearby stops with consistent loading, error, and empty states.
struct NearbyStopsContainerView<Content: View, EmptyView: View>: View {
    let isLoading: Bool
    let errorMessage: String?
    let hasStops: Bool
    let title: String
    let refreshAction: () async -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let emptyState: () -> EmptyView
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                ErrorView(message: errorMessage)
            } else if !hasStops {
                emptyState()
            } else {
                content()
            }
        }
        .navigationTitle(title)
        .refreshable {
            await refreshAction()
        }
    }
}
