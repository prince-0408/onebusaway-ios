import SwiftUI
import MapKit
import OBAKitCore

private struct GlassRowBackground: ViewModifier {
    var cornerRadius: CGFloat = 10
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.8)
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct GlassCapsuleBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.8)
                    )
            )
            .contentShape(Capsule())
    }
}

struct ArrivalDetailView: View {
    let arrival: OBAArrival

    @State private var showTripProblem = false
    @State private var showAlertSheet = false
    @State private var isBookmarked = false
    @State private var hasAlarm = false
    @State private var showAlarmSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Route badge
                Text(arrival.routeShortName ?? arrival.routeID)
                    .font(.system(size: 22, weight: .bold))
                    .padding(.vertical, 2)

                if let headsign = arrival.headsign, !headsign.isEmpty {
                    Text(headsign)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                }

                HStack(spacing: 6) {
                    if arrival.isPredicted {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(OBALoc("arrival_detail.real_time", value: "Real-time", comment: "Real-time arrival status"))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let status = arrival.scheduleStatusLabel {
                        Text(status)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let mins = arrival.minutesFromNow(at: context.date)
                    Text(arrival.timeString(at: context.date))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(mins <= 1 ? .green : .white)
                }

                WatchOccupancyStatusView(occupancyStatus: arrival.occupancyEnum, realtimeData: arrival.isPredicted)

                // Service Alert Banner & Sheet Trigger
                if arrival.hasServiceAlert {
                    Button {
                        showAlertSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(arrival.alertTitle ?? OBALoc("alerts.service_advisory", value: "Service Advisory", comment: "Service advisory title"))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.yellow)
                                    .lineLimit(1)
                                Text(OBALoc("alerts.tap_for_details", value: "Tap to read alert details", comment: "Tap for alert details"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.yellow.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showAlertSheet) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                    Text(arrival.alertTitle ?? OBALoc("alerts.service_advisory", value: "Service Advisory", comment: "Service advisory title"))
                                        .font(.headline)
                                        .foregroundColor(.yellow)
                                }
                                Divider()
                                Text(arrival.alertDescription ?? OBALoc("alerts.no_details", value: "No additional details available.", comment: "No alert details"))
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                    }
                }

                // Glass Quick Action Bar (Bookmark & Alarm)
                HStack(spacing: 6) {
                    Button {
                        if isBookmarked {
                            BookmarksSyncManager.shared.removeBookmark(stopID: arrival.stopID, routeShortName: arrival.routeShortName)
                            isBookmarked = false
                        } else {
                            let bookmark = WatchBookmark(
                                id: UUID(),
                                stopID: arrival.stopID,
                                name: "\(arrival.routeShortName ?? arrival.routeID) - \(arrival.headsign ?? "")",
                                routeShortName: arrival.routeShortName,
                                tripHeadsign: arrival.headsign
                            )
                            BookmarksSyncManager.shared.addBookmark(bookmark)
                            isBookmarked = true
                        }
                        WatchFeedbackGenerator.shared.success()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isBookmarked ? "star.fill" : "star")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                            Text(isBookmarked ? OBALoc("arrival_detail.bookmarked", value: "Saved", comment: "Saved bookmark") : OBALoc("arrival_detail.bookmark", value: "Bookmark", comment: "Bookmark action"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .modifier(GlassCapsuleBackground())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAlarmSetup = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: hasAlarm ? "bell.fill" : "bell")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                            Text(hasAlarm ? OBALoc("arrival_detail.alarm_set", value: "Alarm Set", comment: "Alarm active") : OBALoc("arrival_detail.alarm", value: "Set Alarm", comment: "Set alarm action"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .modifier(GlassCapsuleBackground())
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showAlarmSetup, onDismiss: {
                        hasAlarm = AlarmsSyncManager.shared.hasAlarm(stopID: arrival.stopID, routeShortName: arrival.routeShortName)
                    }) {
                        NavigationStack {
                            AlarmSetupView(
                                stopID: arrival.stopID,
                                stopName: arrival.headsign,
                                routeShortName: arrival.routeShortName,
                                headsign: arrival.headsign,
                                departureTime: arrival.arrivalTime
                            )
                        }
                    }
                }
                .padding(.vertical, 2)

                // Glass Route Details Link (Full Row Tappable)
                if let routeShortName = arrival.routeShortName {
                    NavigationLink {
                        RouteDetailView(route: OBARoute(
                            id: arrival.routeID,
                            shortName: routeShortName,
                            longName: nil,
                            agencyName: nil
                        ))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bus.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(String(format: OBALoc("common.route_fmt", value: "Route %@", comment: "Route name format"), routeShortName))
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text(OBALoc("arrival_detail.view_route_details", value: "View route details", comment: "Action to view route details"))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .modifier(GlassRowBackground())
                    }
                    .buttonStyle(.plain)
                }

                // Glass Trip Schedule Link (Full Row Tappable)
                NavigationLink {
                    TripDetailsView(
                        tripID: arrival.tripID,
                        vehicleID: arrival.vehicleID,
                        routeShortName: arrival.routeShortName,
                        headsign: arrival.headsign,
                        initialTrip: arrival.toTripForLocation()
                    )
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.blue)
                        Text(OBALoc("arrival_detail.view_trip_schedule", value: "View Trip Schedule", comment: "Action to view trip schedule"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .modifier(GlassRowBackground())
                }
                .buttonStyle(.plain)

                // Glass Report Problem Link (Full Row Tappable)
                Button {
                    showTripProblem = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                        Text(OBALoc("arrival_detail.report_trip_problem", value: "Report Trip Problem", comment: "Action to report a trip problem"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .modifier(GlassRowBackground())
                }
                .buttonStyle(.plain)

                // Glass Vehicle Details Link (Full Row Tappable)
                if let vehicleID = arrival.vehicleID {
                    NavigationLink {
                        VehicleSearchView(initialQuery: vehicleID)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.orange)
                            Text(String(format: OBALoc("arrival_detail.view_vehicle_fmt", value: "Vehicle %@", comment: "Action to view vehicle details"), vehicleID.components(separatedBy: "_").last ?? vehicleID))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .modifier(GlassRowBackground())
                    }
                    .buttonStyle(.plain)
                }

                // Mini Live Map (if stop coordinates are present)
                let tripLoc = arrival.toTripForLocation()
                if let lat = tripLoc.latitude,
                   let lon = tripLoc.longitude {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(OBALoc("arrival_detail.live_location", value: "Live Bus Location", comment: "Live vehicle map title"))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Map(initialPosition: .region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))) {
                            Annotation("", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon), anchor: .center) {
                                ZStack {
                                    Circle()
                                        .fill(Color(red: 0.0, green: 0.85, blue: 0.35).opacity(0.3))
                                        .frame(width: 26, height: 26)
                                    Circle()
                                        .fill(Color(red: 0.0, green: 0.82, blue: 0.35))
                                        .frame(width: 20, height: 20)
                                        .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
                                    Image(systemName: "bus.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .mapStyle(.standard(pointsOfInterest: .excludingAll, showsTraffic: false))
                        .frame(height: 110)
                        .cornerRadius(10)
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
        .navigationTitle(arrival.routeShortName ?? OBALoc("common.trip", value: "Trip", comment: "Default title for a trip"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showTripProblem) {
            ProblemReportView(mode: .trip(tripID: arrival.tripID, vehicleID: arrival.vehicleID, stopID: arrival.stopID))
        }
        .userActivity("org.onebusaway.iphone.user_activity.trip") { userActivity in
            userActivity.title = "Trip \(arrival.routeShortName ?? arrival.tripID)"
            userActivity.userInfo = [
                "trip_id": arrival.tripID,
                "stop_id": arrival.stopID,
                "vehicle_id": arrival.vehicleID ?? ""
            ]
            userActivity.isEligibleForHandoff = true
        }
        .onAppear {
            isBookmarked = BookmarksSyncManager.shared.isBookmarked(stopID: arrival.stopID, routeShortName: arrival.routeShortName)
            hasAlarm = AlarmsSyncManager.shared.hasAlarm(stopID: arrival.stopID, routeShortName: arrival.routeShortName)
        }
    }
}
