//
//  ErrorView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

struct ErrorView: View {
    let message: String
    
    var body: some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: OBALoc("common.error", value: "Error", comment: "Error title"),
            message: message
        )
    }
}
