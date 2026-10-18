import SwiftUI
import CoreLocation

struct IncidentDetailSheet: View {
    let incident: Incident
    let userLocation: CLLocation?
    @Environment(\.dismiss) private var dismiss

    private var distanceText: String {
        guard let userLocation else { return "Unknown distance" }
        let incidentLoc = CLLocation(latitude: incident.latitude, longitude: incident.longitude)
        let distance = userLocation.distance(from: incidentLoc)
        if distance < 1000 {
            return "\(Int(distance)) m away"
        } else {
            return String(format: "%.1f km away", distance / 1000)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header card
                    IncidentDetailHeaderView(incident: incident, distanceText: distanceText)

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Alert Summary")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if incident.isPoliceReport {
                                PoliceBadge(size: .regular)
                            }
                        }

                        Text(incident.title)
                            .font(.title3.bold())
                    }

                    // Description / Details
                    if !incident.details.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(incident.isPoliceReport ? "Polisens Rapport" : "Safety Advisory & Details"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(incident.details)
                                .font(.body)
                        }
                    }

                    Divider()

                    // Metadata info
                    VStack(spacing: 12) {
                        IncidentMetadataRow(
                            "Report Source",
                            systemImage: incident.isPoliceReport ? "shield.fill" : "shield.lefthalf.filled",
                            value: incident.isPoliceReport ? "Polisen (Officiell)" : "Anonymous Community Report",
                            color: incident.isPoliceReport ? Color.blue : Color.primary
                        )

                        IncidentMetadataRow(
                            "Freshness",
                            systemImage: incident.decayStatus.icon,
                            value: "\(incident.decayStatus.rawValue) • \(incident.isExpired ? "Older than 24h" : "Active risk")",
                            color: incident.decayStatus == .recent ? .red : (incident.decayStatus == .expired ? .secondary : .orange)
                        )

                        IncidentMetadataRow("Time Reported", systemImage: "clock") {
                            Text("\(incident.timestamp, style: .relative) ago")
                                .fontWeight(.medium)
                        }

                        IncidentMetadataRow("Coordinates", systemImage: "location") {
                            Text(String(format: "%.4f, %.4f", incident.latitude, incident.longitude))
                                .font(.caption.monospaced())
                                .fontWeight(.medium)
                        }
                    }
                    .font(.subheadline)
                }
                .padding()
            }
            .navigationTitle(LocalizedStringKey(incident.isPoliceReport ? "Polisrapport" : "Safety Alert"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
