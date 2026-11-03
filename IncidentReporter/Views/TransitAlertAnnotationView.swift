import SwiftUI

/// Map pin for an SL safety alert: a warning triangle coloured by severity, with the affected transit mode.
struct TransitAlertAnnotationView: View {
    let alert: TransitSafetyAlert
    var isSelected: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: isSelected ? 30 : 24, weight: .bold))
                .foregroundStyle(.white, alert.severity.color.gradient)
                .shadow(color: .black.opacity(0.3), radius: 3, y: 2)

            if let mode = alert.primaryMode {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(mode.color, in: Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1))
                    .offset(x: 6, y: 4)
            }
        }
        .animation(.spring(duration: 0.25), value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("SL alert at \(alert.stopName): \(alert.header)"))
    }
}

#Preview {
    HStack(spacing: 24) {
        TransitAlertAnnotationView(alert: .preview(severity: .high, mode: .metro))
        TransitAlertAnnotationView(alert: .preview(severity: .medium, mode: .train), isSelected: true)
        TransitAlertAnnotationView(alert: .preview(severity: .low, mode: .bus))
    }
    .padding()
}

extension TransitSafetyAlert {
    static func preview(severity: IncidentSeverity = .high, mode: TransitMode = .metro) -> TransitSafetyAlert {
        TransitSafetyAlert(
            id: "1-9001",
            caseID: 1,
            stopName: "T-Centralen",
            coordinate: .init(latitude: 59.3314, longitude: 18.0604),
            header: "Polisinsats vid T-Centralen",
            details: "Tunnelbanetåg på gröna linjen stannar inte vid T-Centralen på grund av en polisinsats.",
            affectedLines: "Tunnelbana 17, 18, 19",
            modes: [mode],
            severity: severity,
            reportedAt: .now.addingTimeInterval(-900)
        )
    }
}
