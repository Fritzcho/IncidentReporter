import SwiftUI

/// A circular map control button that launches or displays the active state of the Safety Timer.
struct SafetyTimerButton: View {
    let isActive: Bool
    let isEscalated: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: isEscalated ? "bell.and.waves.left.and.right.fill" : (isActive ? "timer.circle.fill" : "timer"))
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .symbolEffect(.pulse, isActive: isActive || isEscalated)

                if isActive {
                    Circle()
                        .fill(isEscalated ? Color.red : Color.green)
                        .frame(width: 9, height: 9)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel(isActive ? "Manage active safety timer" : "Start safety timer")
    }

    private var iconColor: Color {
        if isEscalated {
            return .red
        } else if isActive {
            return .green
        } else {
            return .teal
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        SafetyTimerButton(isActive: false, isEscalated: false) {}
        SafetyTimerButton(isActive: true, isEscalated: false) {}
        SafetyTimerButton(isActive: true, isEscalated: true) {}
    }
    .padding()
}
