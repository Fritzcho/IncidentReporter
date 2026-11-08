import SwiftUI

/// A circular button style with material background and tactile press feedback, designed for map overlay controls.
/// Enforces a consistent, uniform diameter across all circular map controls.
struct CircularMapControlButtonStyle: ButtonStyle {
    static let controlSize: CGFloat = 48

    var isFilled: Bool = false
    var fillColor: Color = .green

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: Self.controlSize, height: Self.controlSize)
            .background {
                if isFilled {
                    Circle().fill(fillColor.gradient)
                } else {
                    Circle().fill(.ultraThickMaterial)
                }
            }
            .clipShape(Circle())
            .contentShape(Circle())
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CircularMapControlButtonStyle {
    static var circularMapControl: CircularMapControlButtonStyle {
        CircularMapControlButtonStyle()
    }

    static func circularMapControl(isFilled: Bool = false, fillColor: Color = .green) -> CircularMapControlButtonStyle {
        CircularMapControlButtonStyle(isFilled: isFilled, fillColor: fillColor)
    }
}
