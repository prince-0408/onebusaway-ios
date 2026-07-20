//
//  GlassCapsuleModifier.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI

struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(watchOS 26.0, *) {
            content
                .glassEffect(in: Capsule())
        } else {
            content
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                )
        }
    }
}
