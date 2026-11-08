import SwiftUI

/// A prominent call-to-action button that opens the safe route planner.
struct SafeRouteButton: View {
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                    .font(.body.weight(.semibold))

                Text("Safe Route")
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.green.gradient)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(SafeRouteButtonStyle())
        .accessibilityLabel("Safe route")
        .accessibilityValue(isActive ? Text("Route active") : Text(""))
    }
}

private struct SafeRouteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

#Preview {
    SafeRouteButton {}
        .padding()
}
