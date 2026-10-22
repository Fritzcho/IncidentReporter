import SwiftUI
import CoreLocation

/// Map pin for a nearby subway station, commuter train station or bus stop, with a running/closed dot and the next departure.
struct TransitStopAnnotationView: View {
    let stop: TransitStop
    let isSelected: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let status = stop.status(for: stop.primaryMode, now: context.date)
            let size: CGFloat = isSelected ? 44 : 36

            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        .fill(stop.primaryMode.color.gradient)
                        .overlay {
                            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                                .strokeBorder(.white, lineWidth: 2)
                        }
                        .overlay {
                            Image(systemName: stop.primaryMode.systemImage)
                                .font(.system(size: isSelected ? 19 : 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: size, height: size)
                        .shadow(color: stop.primaryMode.color.opacity(0.4), radius: 5, x: 0, y: 2)

                    Circle()
                        .fill(status.isRunning ? Color.green : Color.orange)
                        .frame(width: 11, height: 11)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        .offset(x: 4, y: -4)
                }

                Text(label(for: status, now: context.date))
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThickMaterial, in: Capsule())
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(stop.name), \(label(for: status, now: context.date))"))
        }
    }

    private func label(for status: TransitServiceStatus, now: Date) -> String {
        switch status {
        case .running(let next, _):
            return "\(next.line) · \(next.countdownText(now: now))"
        case .closed(let next):
            return String(localized: "Closed · \(next.expected.formatted(date: .omitted, time: .shortened))")
        case .noService:
            return String(localized: "No service")
        }
    }
}

#Preview {
    let stop = TransitStop(
        id: 9001,
        name: "T-Centralen",
        coordinate: .init(latitude: 59.3314, longitude: 18.0604),
        modes: [.metro],
        departures: [
            TransitDeparture(
                id: "1", mode: .metro, line: "11", destination: "Akalla",
                scheduled: .now.addingTimeInterval(180), expected: .now.addingTimeInterval(180), platform: "6"
            )
        ],
        fetchedAt: .now
    )
    HStack(spacing: 30) {
        TransitStopAnnotationView(stop: stop, isSelected: false)
        TransitStopAnnotationView(stop: stop, isSelected: true)
    }
    .padding()
}
