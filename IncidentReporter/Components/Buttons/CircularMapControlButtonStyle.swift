import SwiftUI

/// A circular button style with material background and tactile press feedback, designed for map overlay controls.
struct CircularMapControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(14)
            .background(.ultraThickMaterial)
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CircularMapControlButtonStyle {
    static var circularMapControl: CircularMapControlButtonStyle {
        CircularMapControlButtonStyle()
    }
}
