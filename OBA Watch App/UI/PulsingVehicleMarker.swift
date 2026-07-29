//
//  PulsingVehicleMarker.swift
//  OBAWatch Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI

/// Animated live vehicle marker with continuous pulsing radar ring for watchOS map views.
struct PulsingVehicleMarker: View {
    let title: String
    let heading: Double
    var isTracked: Bool = false
    
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Expanding Radar Wave Ring (Blinking effect)
                Circle()
                    .stroke(
                        (isTracked ? Color.green : Color.blue).opacity(isPulsing ? 0.0 : 0.85),
                        lineWidth: isPulsing ? 7 : 2
                    )
                    .scaleEffect(isPulsing ? 1.75 : 1.0)
                    .frame(width: 24, height: 24)
                
                // Core Vehicle Badge
                Circle()
                    .fill(isTracked ? Color.green : Color.blue)
                    .frame(width: 24, height: 24)
                    .shadow(color: (isTracked ? Color.green : Color.blue).opacity(0.6), radius: isPulsing ? 5 : 2)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.5)
                    )
                
                // Rotated Heading Arrow Icon
                Image(systemName: "location.north.navigation.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: heading))
            }
            .onAppear {
                withAnimation(
                    .easeOut(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
            
            // Route Number Tag
            Text(title)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 0.5)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.black.opacity(0.75)))
                .offset(y: 1)
        }
    }
}
