import SwiftUI

/// A card header displaying the incident category icon, title, distance text, and severity badge.
struct IncidentDetailHeaderView: View {
    let incident: Incident
    let distanceText: String

    var body: some View {
        HStack(spacing: 16) {
            CategoryIconView(category: incident.category, size: 56, style: .gradient)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(incident.category.rawValue))
                    .font(.headline)
                    .foregroundStyle(incident.category.color)

                Text(LocalizedStringKey(distanceText))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            SeverityBadge(severity: incident.severity, size: .regular)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
