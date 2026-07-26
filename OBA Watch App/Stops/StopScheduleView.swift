//
//  StopScheduleView.swift
//  OBA Watch App
//
//  Created by Prince Yadav on 31/12/25.
//

import SwiftUI
import OBAKitCore

struct StopScheduleView: View {
    let stopID: OBAStopID
    @State private var selectedDay: ScheduleDay = .today
    @State private var schedule: OBAStopSchedule?
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum ScheduleDay: String, CaseIterable, Identifiable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        var id: String { rawValue }
    }

    private var targetDate: Date {
        switch selectedDay {
        case .today:
            return Date()
        case .tomorrow:
            return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]

    var body: some View {
        List {
            // Day selector section
            Section {
                HStack(spacing: 6) {
                    ForEach(ScheduleDay.allCases) { day in
                        Button {
                            selectedDay = day
                            Task { await load() }
                        } label: {
                            Text(day.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(selectedDay == day ? Color.blue : Color.white.opacity(0.15))
                                )
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowBackground(Color.clear)

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                .listRowBackground(Color.clear)
            } else if groupedStopTimes.isEmpty {
                Section {
                    EmptyStateView(
                        systemImage: "calendar.badge.clock",
                        title: OBALoc("schedule.empty_title", value: "No Departures", comment: "Empty schedule title"),
                        message: OBALoc("schedule.empty_msg", value: "No scheduled trips for this date", comment: "Empty schedule message")
                    )
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedStopTimes, id: \.headsign) { group in
                    Section(header: Text(group.headsign).font(.system(size: 11, weight: .bold))) {
                        LazyVGrid(columns: gridColumns, spacing: 6) {
                            ForEach(group.stopTimes.indices, id: \.self) { idx in
                                let item = group.stopTimes[idx]
                                let isPast = item.departureTime < Date()
                                
                                Text(DateFormatterHelper.timeFormatter.string(from: item.departureTime))
                                    .font(.system(size: 11, weight: isPast ? .regular : .semibold, design: .rounded))
                                    .foregroundColor(isPast ? .secondary.opacity(0.6) : .white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isPast ? Color.white.opacity(0.06) : Color.blue.opacity(0.3))
                                    )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(OBALoc("schedule.title", value: "Schedule", comment: "Schedule title"))
        .task {
            await load()
        }
        .refreshable {
            await load()
        }
    }

    private struct GroupedStopTime {
        let headsign: String
        let stopTimes: [OBAStopScheduleStopTime]
    }

    private var groupedStopTimes: [GroupedStopTime] {
        guard let times = schedule?.stopTimes, !times.isEmpty else { return [] }

        var dict: [String: [OBAStopScheduleStopTime]] = [:]
        for time in times {
            let key = time.stopHeadsign?.isEmpty == false ? time.stopHeadsign! : OBALoc("common.scheduled_trip", value: "Scheduled Trip", comment: "Fallback headsign")
            dict[key, default: []].append(time)
        }

        return dict.keys.sorted().map { key in
            let sortedItems = (dict[key] ?? []).sorted { $0.departureTime < $1.departureTime }
            return GroupedStopTime(headsign: key, stopTimes: sortedItems)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let s = try await WatchAppState.shared.apiClient.fetchScheduleForStop(stopID: stopID, date: targetDate)
            schedule = s
        } catch {
            errorMessage = error.watchOSUserFacingMessage
        }
    }
}

#Preview {
    NavigationStack {
        StopScheduleView(stopID: "1_12345")
    }
}
