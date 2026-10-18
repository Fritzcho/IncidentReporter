import SwiftUI

/// A circular map control button that triggers or schedules a discreet fake call.
struct DiscreetCallButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "phone.badge.waveform.fill")
                .font(.title3)
                .foregroundStyle(Color.purple)
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel("Discreet fake call")
    }
}

#Preview {
    DiscreetCallButton {}
        .padding()
}
