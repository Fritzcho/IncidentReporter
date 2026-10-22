import SwiftUI

/// A pill showing whether a transit mode is currently running at a stop.
struct TransitStatusBadge: View {
    let status: TransitServiceStatus

    private var title: LocalizedStringKey {
        switch status {
        case .running: return "Running"
        case .closed: return "Closed"
        case .noService: return "No service"
        }
    }

    private var color: Color {
        switch status {
        case .running: return .green
        case .closed: return .orange
        case .noService: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let departure = TransitDeparture(
        id: "1", mode: .metro, line: "11", destination: "Akalla",
        scheduled: .now.addingTimeInterval(240), expected: .now.addingTimeInterval(240), platform: "6"
    )
    VStack(spacing: 12) {
        TransitStatusBadge(status: .running(next: departure, lastDeparture: nil))
        TransitStatusBadge(status: .closed(next: departure))
        TransitStatusBadge(status: .noService)
    }
    .padding()
}
