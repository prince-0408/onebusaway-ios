import SwiftUI

struct ItineraryDetailView: View {
    let itinerary: OTPItinerary
    
    var body: some View {
        List {
            Section(header: Text(OBALoc("itinerary.section.summary", value: "Summary", comment: "Itinerary summary section header"))) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(OBALoc("itinerary.label.duration", value: "Duration", comment: "Itinerary duration label"))
                        Spacer()
                        Text(formatDuration(itinerary.duration))
                    }
                    HStack {
                        Text(OBALoc("itinerary.label.walk_time", value: "Walk Time", comment: "Itinerary walk time label"))
                        Spacer()
                        Text(formatDuration(itinerary.walkTime))
                    }
                    HStack {
                        Text(OBALoc("itinerary.label.transfers", value: "Transfers", comment: "Itinerary transfers label"))
                        Spacer()
                        Text("\(itinerary.transfers)")
                    }
                }
                .font(.caption)
            }
            
            Section(header: Text(OBALoc("itinerary.section.directions", value: "Directions", comment: "Itinerary directions section header"))) {
                ForEach(itinerary.legs) { leg in
                    LegDetailRow(leg: leg)
                }
            }
        }
        .navigationTitle(OBALoc("itinerary.nav_title", value: "Details", comment: "Itinerary detail navigation title"))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return String(format: OBALoc("itinerary.duration_minutes_fmt", value: "%d min", comment: "Duration minutes format"), minutes)
    }
}

struct LegDetailRow: View {
    let leg: OTPLeg
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(backgroundColor)
                
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.caption)
                        .bold()
                    
                    if let headsign = leg.headsign {
                        Text(String(format: OBALoc("itinerary.leg.to_headsign_fmt", value: "to %@", comment: "Direction: to [headsign]"), headsign))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                if let steps = leg.steps, !steps.isEmpty {
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if leg.steps != nil && !leg.steps!.isEmpty {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
            }
            
            HStack {
                Text(formatTime(leg.startTime))
                Image(systemName: "arrow.right")
                Text(formatTime(leg.endTime))
                
                Spacer()
                
                Text(formatDuration(leg.duration))
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
            
            // Expanded Step-by-Step Directions
            if isExpanded, let steps = leg.steps, !steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Divider()
                        .padding(.vertical, 2)
                    
                    ForEach(0..<steps.count, id: \.self) { index in
                        let step = steps[index]
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: stepIcon(step))
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                                .padding(.top, 1)
                            
                            Text(stepDescription(step))
                                .font(.system(size: 10))
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 2)
    }
    
    private var title: String {
        if leg.mode.uppercased() == "WALK" {
            return String(format: OBALoc("itinerary.leg.walk_format", value: "Walk %dm", comment: "Walk distance format"), Int(leg.distance))
        } else {
            return String(format: OBALoc("itinerary.leg.title_fmt", value: "%@ - %@", comment: "Leg title format"), leg.routeShortName ?? leg.mode, leg.from.name)
        }
    }
    
    private var iconName: String {
        switch leg.mode.uppercased() {
        case "WALK": return "figure.walk"
        case "BUS": return "bus"
        case "RAIL", "SUBWAY", "TRAM": return "train"
        default: return "questionmark"
        }
    }
    
    private var backgroundColor: Color {
        switch leg.mode.uppercased() {
        case "WALK": return .gray
        case "BUS": return .green
        case "RAIL", "SUBWAY", "TRAM": return .blue
        default: return .secondary
        }
    }
    
    private func stepIcon(_ step: OTPStep) -> String {
        switch step.relativeDirection?.uppercased() {
        case "DEPART": return "location.fill"
        case "LEFT": return "arrow.turn.up.left"
        case "RIGHT": return "arrow.turn.up.right"
        case "SLIGHT_LEFT": return "arrow.up.left"
        case "SLIGHT_RIGHT": return "arrow.up.right"
        case "CONTINUE": return "arrow.up"
        default: return "figure.walk"
        }
    }
    
    private func stepDescription(_ step: OTPStep) -> String {
        let direction: String
        switch step.relativeDirection?.uppercased() {
        case "DEPART":
            direction = OBALoc("itinerary.step.depart", value: "Depart on", comment: "Step instruction: Depart on")
        case "LEFT":
            direction = OBALoc("itinerary.step.left", value: "Turn left on", comment: "Step instruction: Turn left on")
        case "RIGHT":
            direction = OBALoc("itinerary.step.right", value: "Turn right on", comment: "Step instruction: Turn right on")
        case "SLIGHT_LEFT":
            direction = OBALoc("itinerary.step.slight_left", value: "Slight left on", comment: "Step instruction: Slight left on")
        case "SLIGHT_RIGHT":
            direction = OBALoc("itinerary.step.slight_right", value: "Slight right on", comment: "Step instruction: Slight right on")
        case "CONTINUE":
            direction = OBALoc("itinerary.step.continue", value: "Continue on", comment: "Step instruction: Continue on")
        default:
            direction = OBALoc("itinerary.step.walk_on", value: "Walk on", comment: "Step instruction: Walk on")
        }
        
        return "\(direction) \(step.streetName) (\(Int(step.distance))m)"
    }
    
    private func formatTime(_ date: Date) -> String {
        return Self.timeFormatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return String(format: OBALoc("itinerary.duration_minutes_short_fmt", value: "%dm", comment: "Short duration minutes format"), minutes)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()
}
