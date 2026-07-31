//
//  ServiceAlertDetailView.swift
//  OBA Watch App
//
//  Created by Prince Yadav on 26/07/26.
//

import SwiftUI
import OBAKitCore

struct ServiceAlertDetailView: View {
    let alert: WatchServiceAlert
    @State private var infoMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(3)

                        if let severity = alert.severity, !severity.isEmpty {
                            Text(severity.capitalized)
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.3)))
                                .foregroundColor(.orange)
                        }
                    }
                }

                Divider()

                // Active Time Range
                if let rangeString = timeRangeString {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(rangeString)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Affected Routes Chips
                if let routes = alert.affectedRoutes, !routes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(OBALoc("service_alert.affected_routes", value: "Affected Routes", comment: "Affected routes header"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(routes, id: \.self) { route in
                                    Text(route)
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.brand))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }

                // Alert Body Text
                if let body = alert.body, !body.isEmpty {
                    Text(body.replacingOccurrences(of: "<br>", with: "\n").replacingOccurrences(of: "<br/>", with: "\n"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(2)
                        .padding(.top, 4)
                } else {
                    Text(OBALoc("transit_alert.no_additional_details.body", value: "No additional details available.", comment: "Notice when no body text"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Divider()
                    .padding(.vertical, 4)

                // Open on iPhone action
                Button {
                    let ok = DeepLinkSyncManager.shared.openAlertsOnPhone()
                    if !ok {
                        infoMessage = OBALoc("deeplink.failure", value: "Unable to contact iPhone. Make sure your devices are connected.", comment: "Deep link failure")
                    } else {
                        WatchFeedbackGenerator.shared.success()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Label(OBALoc("common.open_on_iphone", value: "Open on iPhone", comment: "Open on iPhone button"), systemImage: "iphone")
                            .font(.system(size: 12, weight: .semibold))
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.brand)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle(OBALoc("service_alerts.detail_title", value: "Alert Detail", comment: "Alert detail title"))
        .alert(OBALoc("common.info", value: "Info", comment: "Info title"), isPresented: Binding(
            get: { infoMessage != nil },
            set: { if !$0 { infoMessage = nil } }
        )) {
            Button(OBALoc("common.ok", value: "OK", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
    }

    private var timeRangeString: String? {
        let formatter = DateFormatterHelper.timeFormatter
        if let start = alert.startDate, let end = alert.endDate {
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        } else if let end = alert.endDate {
            return String(format: OBALoc("alerts.valid_until_fmt", value: "Until %@", comment: "Valid until date format"), formatter.string(from: end))
        } else if let start = alert.startDate {
            return String(format: OBALoc("alerts.valid_from_fmt", value: "From %@", comment: "Valid from date format"), formatter.string(from: start))
        }
        return nil
    }
}

#Preview {
    NavigationStack {
        ServiceAlertDetailView(alert: WatchServiceAlert(
            id: "1",
            title: "Route 10 Detour",
            body: "Buses are detouring via 3rd Ave due to construction on Pine St.",
            severity: "WARNING",
            affectedRoutes: ["10", "11"],
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400)
        ))
    }
}
