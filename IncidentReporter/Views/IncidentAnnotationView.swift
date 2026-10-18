import SwiftUI

struct IncidentAnnotationView: View {
    let incident: Incident
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Outer pulse ring for recent active threats (< 4h)
                if incident.decayStatus == .recent {
                    Circle()
                        .stroke(incident.category.color.opacity(0.35), lineWidth: 3)
                        .frame(width: isSelected ? 56 : 46, height: isSelected ? 56 : 46)
                }

                ZStack {
                    Circle()
                        .fill(incident.category.color.gradient)
                        .frame(width: isSelected ? 48 : 38, height: isSelected ? 48 : 38)
                        .shadow(
                            color: incident.category.color.opacity(incident.decayStatus == .expired ? 0.1 : 0.4),
                            radius: 6,
                            x: 0,
                            y: 3
                        )

                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: isSelected ? 48 : 38, height: isSelected ? 48 : 38)

                    Image(systemName: incident.category.systemImage)
                        .font(.system(size: isSelected ? 20 : 16, weight: .bold))
                        .foregroundStyle(.white)
                }

                if incident.isPoliceReport {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.blue)
                    }
                    .offset(x: 4, y: -4)
                }
            }

            // Severity dot indicator
            Circle()
                .fill(incident.severity.color)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white, lineWidth: 1))
        }
        .opacity(incident.decayStatus.opacity)
        .saturation(incident.decayStatus == .expired ? 0.35 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
