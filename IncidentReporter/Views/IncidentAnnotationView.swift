import SwiftUI

struct IncidentAnnotationView: View {
    let incident: Incident
    let isSelected: Bool

    @State private var isPulsing = false

    private var circleSize: CGFloat {
        isSelected ? 48 : 38
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .center) {
                // Animated concentric pulse ring for recent active threats (< 4h)
                if incident.decayStatus == .recent {
                    Circle()
                        .stroke(incident.category.color.opacity(isPulsing ? 0.0 : 0.6), lineWidth: 2)
                        .background(
                            Circle()
                                .fill(incident.category.color.opacity(isPulsing ? 0.02 : 0.18))
                        )
                        .frame(width: circleSize + 14, height: circleSize + 14)
                        .scaleEffect(isPulsing ? 1.3 : 0.95)
                }

                // Main Category Icon Circle (centered)
                ZStack {
                    Circle()
                        .fill(incident.category.color.gradient)
                        .frame(width: circleSize, height: circleSize)
                        .shadow(
                            color: incident.category.color.opacity(incident.decayStatus == .expired ? 0.1 : 0.4),
                            radius: 6,
                            x: 0,
                            y: 3
                        )

                    Circle()
                        .strokeBorder(.white, lineWidth: 2)
                        .frame(width: circleSize, height: circleSize)

                    Image(systemName: incident.category.systemImage)
                        .font(.system(size: isSelected ? 20 : 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(alignment: .topTrailing) {
                    // Official Police Badge indicator pinned to icon's corner without shifting the center
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
            }
            .frame(width: circleSize + 18, height: circleSize + 18)

            // Severity dot indicator
            Circle()
                .fill(incident.severity.color)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(.white, lineWidth: 1))
        }
        .opacity(incident.decayStatus.opacity)
        .saturation(incident.decayStatus == .expired ? 0.35 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onAppear {
            if incident.decayStatus == .recent {
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }
        }
    }
}
