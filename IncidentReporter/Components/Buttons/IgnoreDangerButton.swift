import SwiftUI

/// Lets the user mark a danger as over for themselves only, or start being warned about it again.
/// Explains that other users keep seeing the warning.
struct IgnoreDangerButton: View {
    let isIgnored: Bool
    let onIgnore: () -> Void
    let onRestore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isIgnored {
                Button(action: onRestore) {
                    Label("Warn me about this again", systemImage: "exclamationmark.triangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Text("You marked this danger as over. It doesn't trigger alerts or affect your safe routes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button(action: onIgnore) {
                    Label("It's over — ignore for me", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.green)
                Text("Only hides the warning for you. Everyone else still sees it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        IgnoreDangerButton(isIgnored: false, onIgnore: {}, onRestore: {})
        IgnoreDangerButton(isIgnored: true, onIgnore: {}, onRestore: {})
    }
    .padding()
}
