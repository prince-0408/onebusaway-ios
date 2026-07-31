//
//  Color+Theme.swift
//  OBA Watch App
//

import SwiftUI
import OBAKitCore

public extension Color {
    /// Dynamic brand accent color for the active product target:
    /// - KiedyBus Watch Target: Blue (`#4596EC`)
    /// - OneBusAway Watch Target: Green (`#78AA36`)
    static var brand: Color {
        Color(uiColor: ThemeColors.shared.brand)
    }
}

public extension ShapeStyle where Self == Color {
    /// Dynamic brand accent color for SwiftUI modifiers expecting ShapeStyle.
    static var brand: Color {
        Color.brand
    }
}
