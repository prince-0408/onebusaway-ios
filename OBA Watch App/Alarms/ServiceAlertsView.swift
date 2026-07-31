import SwiftUI
import OBAKitCore

struct ServiceAlertsView: View {
    @State private var alerts: [WatchServiceAlert] = ServiceAlertsSyncManager.shared.currentAlerts()
    @State private var infoMessage: String?

    var body: some View {
        List {
            if alerts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(OBALoc("alerts.empty.title", value: "No Notifications", comment: "No alerts title"))
                        .font(.headline)
                    Text(OBALoc("alerts.empty.subtitle", value: "No active notifications", comment: "No alerts subtitle"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(alerts) { alert in
                    NavigationLink {
                        ServiceAlertDetailView(alert: alert)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top, spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text(alert.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .lineLimit(2)
                            }
                            
                            if let body = alert.body, !body.isEmpty {
                                Text(body)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            if let routes = alert.affectedRoutes, !routes.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Routes: \(routes.joined(separator: ", "))")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.brand)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle(OBALoc("service_alerts.nav_title", value: "Notifications", comment: "Service alerts navigation title"))
        .onReceive(NotificationCenter.default.publisher(for: ServiceAlertsSyncManager.alertsUpdatedNotification)) { _ in
            alerts = ServiceAlertsSyncManager.shared.currentAlerts()
        }
        .alert(OBALoc("common.info", value: "Info", comment: "Alert title for information"), isPresented: Binding(
            get: { infoMessage != nil },
            set: { if !$0 { infoMessage = nil } }
        )) {
            Button(OBALoc("common.ok", value: "OK", comment: "OK button"), role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
    }
}
