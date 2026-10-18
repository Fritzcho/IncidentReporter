import SwiftUI

/// A circular map control button that triggers a manual sync with Swedish Police events, showing a spinning animation while syncing.
struct PoliceSyncButton: View {
    let isSyncing: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                .font(.title3)
                .foregroundStyle(Color.blue)
                .rotationEffect(.degrees(isSyncing ? 360 : 0))
                .animation(isSyncing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isSyncing)
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel("Sync police events")
    }
}

#Preview {
    HStack {
        PoliceSyncButton(isSyncing: false) {}
        PoliceSyncButton(isSyncing: true) {}
    }
    .padding()
}
