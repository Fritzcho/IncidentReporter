import SwiftUI
import CoreLocation

struct ApproachingIncidentBanner: View {
    let incident: Incident
    let userLocation: CLLocation?
    let onDismiss: () -> Void

    private var distanceText: String {
        guard let userLocation else { return "Nearby" }
        let incidentLoc = CLLocation(latitude: incident.latitude, longitude: incident.longitude)
        let distance = userLocation.distance(from: incidentLoc)
        if distance < 1000 {
            return "\(Int(distance)) m ahead"
        } else {
            return String(format: "%.1f km ahead", distance / 1000)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            CategoryIconView(category: incident.category, size: 44, style: .tinted)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("SAFETY ALERT AHEAD")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(distanceText)
                        .font(.caption2.bold())
                        .foregroundStyle(incident.severity.color)
                }

                Text(incident.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)

                if !incident.details.isEmpty {
                    Text(incident.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }
}
