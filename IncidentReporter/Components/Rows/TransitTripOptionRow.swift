import SwiftUI

/// One public transport option in a list: times, lines in order, changes and any dangers on the way.
struct TransitTripOptionRow: View {
    let trip: TransitTrip
    var dangerCount: Int = 0
    var isSelected: Bool = false
    var isRecommended: Bool = false

    private var minutes: Int {
        guard let departure = trip.departure, let arrival = trip.arrival else { return 0 }
        return Int((arrival.timeIntervalSince(departure) / 60).rounded())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let departure = trip.departure, let arrival = trip.arrival {
                        Text("\(departure, style: .time) – \(arrival, style: .time)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    Text("\(minutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if isRecommended {
                        Text("Safest fast")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15), in: Capsule())
                    }
                }

                // Lines in order, with a chevron between each ride
                HStack(spacing: 4) {
                    ForEach(Array(trip.rides.enumerated()), id: \.offset) { index, ride in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        TransitLineBadge(mode: ride.mode, line: ride.line)
                    }
                }

                HStack(spacing: 8) {
                    Text(trip.changes == 0 ? "No changes" : "\(trip.changes) change(s)")
                    if let first = trip.firstRideDeparture {
                        Text("First departure \(first, style: .time)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if dangerCount > 0 {
                    Label("\(dangerCount) danger(s) on the way", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.green : Color.secondary.opacity(0.5))
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    List {
        TransitTripOptionRow(trip: .preview, isSelected: true, isRecommended: true)
        TransitTripOptionRow(trip: .preview, dangerCount: 1)
    }
}
