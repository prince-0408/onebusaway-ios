import SwiftUI
import OBAKitCore
import CoreLocation

enum ProblemReportMode {
    case stop(stopID: OBAStopID)
    case trip(tripID: String, vehicleID: String?, stopID: OBAStopID?)
}

private let quickProblems: [(code: String, title: String, icon: String)] = [
    ("vehicle_never_came", "Bus Never Came", "bus.fill"),
    ("vehicle_arrived_early", "Bus Arrived Early", "clock.arrow.circlepath"),
    ("vehicle_arrived_late", "Bus Arrived Late", "clock.badge.exclamationmark"),
    ("wrong_headsign", "Wrong Headsign", "signpost.right")
]

struct ProblemReportView: View {
    let mode: ProblemReportMode
    @State private var code: String = "vehicle_never_came"
    @State private var comment: String = ""
    @State private var includeLocation: Bool = true
    @State private var userOnVehicle: Bool = false
    @State private var serviceDate: Date = Date()
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section(OBALoc("problem_report.select_issue", value: "Select Issue", comment: "Select issue header")) {
                ForEach(quickProblems, id: \.code) { item in
                    Button {
                        self.code = item.code
                        Task { await submit() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .foregroundColor(.orange)
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            if code == item.code {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(isSubmitting)
                }
            }

            switch mode {
            case .stop(let stopID):
                Section(String(format: OBALoc("problem_report.stop_fmt", value: "Stop %@", comment: "Stop header"), stopID)) {
                    Toggle(OBALoc("problem_report.include_location", value: "Include location", comment: "Include location"), isOn: $includeLocation)
                }
            case .trip(let tripID, _, let stopID):
                Section(String(format: OBALoc("problem_report.trip_fmt", value: "Trip %@", comment: "Trip header"), tripID)) {
                    Toggle(OBALoc("problem_report.on_vehicle", value: "On vehicle", comment: "On vehicle"), isOn: $userOnVehicle)
                    if let stopID {
                        Text(String(format: OBALoc("problem_report.stop_fmt", value: "Stop %@", comment: "Stop header"), stopID))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
            }
            Section {
                Button(isSubmitting ? OBALoc("problem_report.submitting", value: "Submitting...", comment: "Submitting") : OBALoc("problem_report.submit", value: "Submit", comment: "Submit")) {
                    Task { await submit() }
                }
                .disabled(isSubmitting || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle(OBALoc("problem_report.title", value: "Report Problem", comment: "Report Problem"))
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            switch mode {
            case .stop(let stopID):
                let location = includeLocation ? WatchAppState.shared.currentLocation : nil
                let report = OBAStopProblemReport(stopID: stopID, code: code, comment: comment.isEmpty ? nil : comment, location: location)
                try await WatchAppState.shared.apiClient.submitStopProblem(report)
            case .trip(let tripID, let vehicleID, let stopID):
                let report = OBATripProblemReport(tripID: tripID, serviceDate: serviceDate, vehicleID: vehicleID, stopID: stopID, code: code, comment: comment.isEmpty ? nil : comment, userOnVehicle: userOnVehicle, location: WatchAppState.shared.currentLocation)
                try await WatchAppState.shared.apiClient.submitTripProblem(report)
            }
            dismiss()
        } catch {
            errorMessage = error.watchOSUserFacingMessage
        }
    }
}
