//
//  TransferBannerView.swift
//  OBAWatch Watch App
//

import SwiftUI
import OBAKitCore

struct TransferBannerView: View {
    let context: TransferContext
    var stopName: String? = nil
    var connectingArrival: OBAArrival? = nil

    private var arrivalTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: context.arrivalTime)
    }

    var body: some View {
        NavigationLink {
            ConnectionGuideView(context: context, stopName: stopName, connectingArrival: connectingArrival)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.brand)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(OBALoc("transfer_banner.title", value: "Transfer Connection", comment: "Transfer banner header title"))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.brand)

                            Text(String(format: OBALoc("transfer_banner.from_route_fmt", value: "From Route %@", comment: "Origin route for transfer"), context.fromRouteDisplay))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text(String(format: OBALoc("transfer_banner.arrival_fmt", value: "Arr: %@", comment: "Arrival time label"), arrivalTimeString))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.brand)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.brand.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.brand.opacity(0.4), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
