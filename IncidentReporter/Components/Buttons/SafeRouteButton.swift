import SwiftUI

/// A circular map control that opens the safe route planner. Shown filled while a route is active.
struct SafeRouteButton: View {
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath.fill")
                .font(.title3)
                .foregroundStyle(isActive ? Color.white : Color.green)
                .frame(width: 30, height: 30)
                .background {
                    if isActive {
                        Circle().fill(Color.green.gradient)
                    }
                }
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel("Safe route")
        .accessibilityValue(isActive ? Text("Route active") : Text(""))
    }
}

#Preview {
    HStack(spacing: 16) {
        SafeRouteButton {}
        SafeRouteButton(isActive: true) {}
    }
    .padding()
}
