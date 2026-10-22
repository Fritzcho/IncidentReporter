import SwiftUI

/// A circular map control button that opens the taxi launcher.
struct TaxiCallButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "car.fill")
                .font(.title3)
                .foregroundStyle(Color.yellow.gradient)
                .shadow(color: .black.opacity(0.25), radius: 0.5)
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel("Call a taxi")
    }
}

#Preview {
    TaxiCallButton {}
        .padding()
}
