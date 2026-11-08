import SwiftUI

/// One step of a trip in a vertical timeline: a walk, or a ride with where to get on, the platform,
/// the departure (with delay), the stops on the way and where to get off.
struct TripLegRow: View {
    let leg: TripLeg
    /// Whether this ride starts with a change from another line
    var isChange: Bool = false
    var dangerNames: [String] = []
    @State private var showsStops = false

    private var accent: Color { leg.mode?.color ?? .secondary }

    private var minutes: Int { max(1, Int((leg.duration / 60).rounded())) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline: solid for rides, dotted for walks
            VStack(spacing: 0) {
                Image(systemName: leg.mode?.systemImage ?? "figure.walk")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(leg.isWalk ? Color.secondary : .white)
                    .frame(width: 26, height: 26)
                    .background(leg.isWalk ? Color.secondary.opacity(0.15) : accent, in: Circle())
                Rectangle()
                    .fill(accent.opacity(leg.isWalk ? 0.35 : 0.9))
                    .frame(width: leg.isWalk ? 2 : 4)
                    .frame(maxHeight: .infinity)
                    .mask {
                        if leg.isWalk {
                            VStack(spacing: 3) {
                                ForEach(0..<40, id: \.self) { _ in Circle().frame(width: 3, height: 3) }
                            }
                        } else {
                            Rectangle()
                        }
                    }
            }
            .frame(width: 26)

            VStack(alignment: .leading, spacing: 6) {
                if leg.isWalk {
                    walkContent
                } else {
                    rideContent
                }

                ForEach(dangerNames, id: \.self) { name in
                    Label(name, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.bottom, 14)
        }
    }

    @ViewBuilder
    private var walkContent: some View {
        Text(leg.isTransfer ? "Change: walk \(minutes) min to \(leg.to.name)" : "Walk \(minutes) min to \(leg.to.name)")
            .font(.subheadline.weight(.medium))
        if let time = leg.from.time {
            Text("Start \(time, style: .time)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var rideContent: some View {
        HStack(spacing: 6) {
            if isChange {
                Text("Change to")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            TransitLineBadge(mode: leg.mode, line: leg.line)
            if let direction = leg.direction {
                Text("towards \(direction)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
        }

        stopLine(prefix: "Get on at", stop: leg.from, showsPlatform: true)

        if !leg.intermediateStops.isEmpty {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showsStops.toggle() }
            } label: {
                Label(
                    showsStops ? "Hide stops" : "\(leg.intermediateStops.count + 1) stops · \(minutes) min",
                    systemImage: showsStops ? "chevron.up" : "chevron.down"
                )
                .font(.caption.weight(.medium))
            }
            .buttonStyle(.borderless)

            if showsStops {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(leg.intermediateStops, id: \.self) { stop in
                        HStack {
                            Text(stop.name)
                            Spacer()
                            if let time = stop.time {
                                Text(time, style: .time)
                                    .monospacedDigit()
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
            }
        }

        stopLine(prefix: "Get off at", stop: leg.to, showsPlatform: false)
    }

    private func stopLine(prefix: LocalizedStringKey, stop: TripStop, showsPlatform: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(prefix)
                .foregroundStyle(.secondary)
            Text(stop.name)
                .fontWeight(.semibold)
            if showsPlatform, let platform = stop.platform, !platform.isEmpty {
                Text("· platform \(platform)")
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if let time = stop.time {
                Text(time, style: .time)
                    .monospacedDigit()
                    .fontWeight(.semibold)
                if stop.delayMinutes > 0 {
                    Text("+\(stop.delayMinutes)")
                        .foregroundStyle(.red)
                        .monospacedDigit()
                }
            }
        }
        .font(.caption)
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(TransitTrip.preview.legs.enumerated()), id: \.element.id) { index, leg in
                TripLegRow(leg: leg, isChange: index > 2 && !leg.isWalk,
                           dangerNames: index == 0 ? ["Skadegörelse (Stockholm)"] : [])
            }
        }
        .padding()
    }
}

extension TransitTrip {
    /// Kungsträdgården → T-Centralen → Stockholm City → Sundbyberg, for previews
    static var preview: TransitTrip {
        let now = Date()
        func stop(_ name: String, _ lat: Double, _ lon: Double, _ minutes: Double, platform: String? = nil, delay: Double = 0) -> TripStop {
            let planned = now.addingTimeInterval(minutes * 60)
            return TripStop(name: name, coordinate: .init(latitude: lat, longitude: lon), platform: platform,
                            plannedTime: planned, estimatedTime: planned.addingTimeInterval(delay * 60))
        }
        let kungs = stop("Kungsträdgården", 59.3311, 18.0727, 4, platform: "1")
        let tc = stop("T-Centralen", 59.3314, 18.0604, 6)
        let city = stop("Stockholm City", 59.3307, 18.0590, 10, platform: "2", delay: 2)
        let sundbyberg = stop("Sundbyberg", 59.3610, 17.9715, 18)
        return TransitTrip(legs: [
            TripLeg(id: 0, mode: nil, line: nil, direction: nil, from: stop("Kungsträdgårdsgatan 15", 59.3317, 18.0715, 0), to: kungs,
                    intermediateStops: [], coordinates: [], isTransfer: false),
            TripLeg(id: 1, mode: .metro, line: "11", direction: "Akalla", from: kungs, to: tc,
                    intermediateStops: [], coordinates: [], isTransfer: false),
            TripLeg(id: 2, mode: nil, line: nil, direction: nil, from: tc, to: city,
                    intermediateStops: [], coordinates: [], isTransfer: true),
            TripLeg(id: 3, mode: .train, line: "43", direction: "Kallhäll", from: city, to: sundbyberg,
                    intermediateStops: [stop("Odenplan", 59.3428, 18.0493, 12), stop("Karlberg", 59.3398, 18.0300, 14)],
                    coordinates: [], isTransfer: false)
        ])
    }
}
