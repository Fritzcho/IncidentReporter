import SwiftUI

/// A compact line tag, e.g. a blue subway icon with "10", coloured by transit mode. Shows a walking
/// figure when there's no mode.
struct TransitLineBadge: View {
    let mode: TransitMode?
    var line: String?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: mode?.systemImage ?? "figure.walk")
                .font(.caption2.weight(.bold))
            if let line, !line.isEmpty {
                Text(line)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(mode == nil ? Color.secondary : .white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            mode?.color ?? Color.secondary.opacity(0.15),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mode.map { Text("\($0.title) \(line ?? "")") } ?? Text("Walk"))
    }
}

#Preview {
    HStack {
        TransitLineBadge(mode: nil)
        TransitLineBadge(mode: .metro, line: "10")
        TransitLineBadge(mode: .train, line: "43X")
        TransitLineBadge(mode: .bus, line: "122")
        TransitLineBadge(mode: .tram, line: "7")
    }
    .padding()
}
