//
//  MoreView.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label(OBALoc("common.settings", value: "Settings", comment: "Title for settings menu item"), systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle(OBALoc("common.more", value: "More", comment: "Title for the More screen"))
        }
    }
}
