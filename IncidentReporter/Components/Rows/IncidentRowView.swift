import SwiftUI

/// A reusable row component for displaying an incident in a list.
struct IncidentRowView: View {
    let incident: Incident

    var body: some View {
        HStack(spacing: 14) {
            CategoryIconView(category: incident.category, size: 44, style: .tinted)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if incident.isPoliceReport {
                        PoliceBadge(size: .compact)
                    }

                    if incident.hasVoiceMemo {
                        VoiceMemoBadge(durationSeconds: incident.audioDurationSeconds)
                    }

                    Text(incident.title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    SeverityBadge(severity: incident.severity, size: .compact)
                }

                if !incident.details.isEmpty {
                    Text(incident.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(incident.reportedBy)
                    Text("•")
                    Text("\(incident.timestamp, style: .relative) ago")

                    if incident.decayStatus == .recent {
                        Text("•")
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                            Text("Recent")
                        }
                        .foregroundStyle(.red)
                        .fontWeight(.semibold)
                    } else if incident.decayStatus == .expired {
                        Text("•")
                        Text("Historical")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .opacity(incident.decayStatus.opacity)
    }
}
