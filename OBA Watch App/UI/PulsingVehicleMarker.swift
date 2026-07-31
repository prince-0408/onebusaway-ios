//
//  PulsingVehicleMarker.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI

/// Clean, high-contrast live vehicle marker pin for watchOS map views.
struct PulsingVehicleMarker: View {
    let title: String
    let heading: Double
    var isTracked: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Core Vehicle Badge with crisp white border ring (No glowing green aura)
                Circle()
                    .fill(Color.brand)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.8)
                    )
                
                // Rotated Heading Arrow Icon
                if heading != 0.0 {
                    Image(systemName: "location.north.navigation.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(Angle(degrees: heading))
                } else {
                    Image(systemName: "bus.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Route Number Tag
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.85)))
                    .offset(y: 1)
            }
        }
    }
}
