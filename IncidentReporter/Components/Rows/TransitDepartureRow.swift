import SwiftUI

/// A list row for one departure: line badge, destination, platform and live countdown.
struct TransitDepartureRow: View {
    let departure: TransitDeparture
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            Text(departure.line)
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(.white)
                .frame(minWidth: 36)
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .background(departure.mode.color.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(departure.destination)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let platform = departure.platform {
                    Text("Platform \(platform)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(departure.countdownText(now: now))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                if departure.delayMinutes > 0 {
                    Text("+\(departure.delayMinutes) min late")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

extension TransitDeparture {
    /// "Now", "4 min" within the hour, otherwise the clock time (e.g. "05:12").
    func countdownText(now: Date) -> String {
        let minutes = Int(expected.timeIntervalSince(now) / 60)
        if minutes < 1 {
            return String(localized: "Now")
        }
        if minutes < 60 {
            return String(localized: "\(minutes) min")
        }
        return expected.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    List {
        TransitDepartureRow(
            departure: TransitDeparture(
                id: "1", mode: .metro, line: "11", destination: "Akalla",
                scheduled: .now.addingTimeInterval(30), expected: .now.addingTimeInterval(30), platform: "6"
            ),
            now: .now
        )
        TransitDepartureRow(
            departure: TransitDeparture(
                id: "2", mode: .bus, line: "69", destination: "Blockhusudden",
                scheduled: .now.addingTimeInterval(300), expected: .now.addingTimeInterval(480), platform: "C"
            ),
            now: .now
        )
        TransitDepartureRow(
            departure: TransitDeparture(
                id: "3", mode: .bus, line: "4", destination: "Radiohuset",
                scheduled: .now.addingTimeInterval(5400), expected: .now.addingTimeInterval(5400), platform: nil
            ),
            now: .now
        )
    }
}
