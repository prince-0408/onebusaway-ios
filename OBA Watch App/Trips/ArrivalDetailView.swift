import SwiftUI
import MapKit
import OBAKitCore

struct ArrivalDetailView: View {
    let arrival: OBAArrival

    @State private var showTripProblem = false
    @State private var showAlertSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Route badge
                Text(arrival.routeShortName ?? arrival.routeID)
                    .font(.system(size: 22, weight: .bold))
                    .padding(.vertical, 4)

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

                // Service Alert Banner & Sheet Trigger
                if arrival.hasServiceAlert {
                    Button {
                        showAlertSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(arrival.alertTitle ?? OBALoc("alerts.service_advisory", value: "Service Advisory", comment: "Service advisory title"))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                                    .lineLimit(1)
                                Text(OBALoc("alerts.tap_for_details", value: "Tap to read alert details", comment: "Tap for alert details"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.yellow.opacity(0.15))
                        .cornerRadius(10)
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

                // Route details
                if let routeShortName = arrival.routeShortName {
                    NavigationLink {
                        RouteDetailView(route: OBARoute(
                            id: arrival.routeID,
                            shortName: routeShortName,
                            longName: nil,
                            agencyName: nil
                        ))
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bus.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: OBALoc("common.route_fmt", value: "Route %@", comment: "Route name format"), routeShortName))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(OBALoc("arrival_detail.view_route_details", value: "View route details", comment: "Action to view route details"))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Trip Schedule Link
                NavigationLink {
                    TripDetailsView(
                        tripID: arrival.tripID,
                        vehicleID: arrival.vehicleID,
                        routeShortName: arrival.routeShortName,
                        headsign: arrival.headsign,
                        initialTrip: arrival.toTripForLocation()
                    )
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .foregroundColor(.blue)
                        Text(OBALoc("arrival_detail.view_trip_schedule", value: "View Trip Schedule", comment: "Action to view trip schedule"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                Button {
                    showTripProblem = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundColor(.red)
                        Text(OBALoc("arrival_detail.report_trip_problem", value: "Report Trip Problem", comment: "Action to report a trip problem"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Vehicle Details Link
                if let vehicleID = arrival.vehicleID {
                    NavigationLink {
                        VehicleSearchView(initialQuery: vehicleID)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bus")
                                .foregroundColor(.orange)
                            Text(String(format: OBALoc("arrival_detail.view_vehicle_fmt", value: "View Vehicle %@", comment: "Action to view vehicle details"), vehicleID.components(separatedBy: "_").last ?? vehicleID))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(OBALoc("arrival_detail.departure_in", value: "Departure in", comment: "Label for departure time"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(arrival.timeString)
                        .font(.title3)
                        .fontWeight(.semibold)
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
                            Marker(
                                arrival.routeShortName ?? "Bus",
                                systemImage: "bus.fill",
                                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)
                            )
                            .tint(.green)
                        }
                        .frame(height: 120)
                        .cornerRadius(12)
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(arrival.routeShortName ?? OBALoc("common.trip", value: "Trip", comment: "Default title for a trip"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showTripProblem) {
            ProblemReportView(mode: .trip(tripID: arrival.tripID, vehicleID: arrival.vehicleID, stopID: arrival.stopID))
        }
    }
}

//#Preview {
//    ArrivalDetailView(arrival: OBAArrival(
//        id: "demo",
//        stopID: "1",
//        routeID: "10", tripID: <#OBATripID#>,
//        routeShortName: "10",
//        headsign: "Downtown",
//        minutesFromNow: 5,
//        isPredicted: true
//    ))
//}
