import SwiftUI
import CoreLocation

/// Details of an SL safety alert, with the option to ignore it for this user only.
struct TransitAlertDetailSheet: View {
    let alert: TransitSafetyAlert
    let userLocation: CLLocation?
    @State private var ignoredStore = IgnoredIncidentStore.shared
    @Environment(\.dismiss) private var dismiss

    private var distanceText: String? {
        guard let userLocation else { return nil }
        let distance = userLocation.distance(from: CLLocation(latitude: alert.coordinate.latitude, longitude: alert.coordinate.longitude))
        if distance < 1000 {
            return String(localized: "\(Int(distance)) m away")
        }
        return String(localized: "\(distance / 1000, specifier: "%.1f") km away")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        TransitAlertAnnotationView(alert: alert, isSelected: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(alert.stopName)
                                .font(.title3.bold())
                            if let distanceText {
                                Text(distanceText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        SeverityBadge(severity: alert.severity, size: .regular)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(alert.header)
                            .font(.headline)
                        if !alert.details.isEmpty {
                            Text(alert.details)
                                .font(.body)
                        }
                    }

                    Divider()

                    VStack(spacing: 12) {
                        IncidentMetadataRow(
                            "Source",
                            systemImage: "tram.fill",
                            value: "SL traffic information",
                            color: .blue
                        )
                        if let lines = alert.affectedLines, !lines.isEmpty {
                            IncidentMetadataRow("Affects", systemImage: "point.3.connected.trianglepath.dotted") {
                                Text(lines)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        IncidentMetadataRow("Published", systemImage: "clock") {
                            Text("\(alert.reportedAt, style: .relative) ago")
                                .fontWeight(.medium)
                        }
                    }
                    .font(.subheadline)

                    Divider()

                    IgnoreDangerButton(isIgnored: ignoredStore.isIgnored(key: alert.ignoreKey)) {
                        ignoredStore.ignore(key: alert.ignoreKey)
                        dismiss()
                    } onRestore: {
                        ignoredStore.restore(key: alert.ignoreKey)
                    }
                }
                .padding()
            }
            .navigationTitle("SL safety alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    TransitAlertDetailSheet(alert: .preview(), userLocation: CLLocation(latitude: 59.3326, longitude: 18.0649))
}
