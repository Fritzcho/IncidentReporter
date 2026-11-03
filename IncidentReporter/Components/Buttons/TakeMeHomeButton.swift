import SwiftUI

/// One-tap safe route home. Names the temporary home when one is active, so it's clear where it goes.
struct TakeMeHomeButton: View {
    /// e.g. "Anna's place" while a temporary home is active; nil for the normal home
    var temporaryHomeLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: temporaryHomeLabel == nil ? "house.fill" : "moon.zzz.fill")
                    .font(.subheadline.weight(.bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Take me home")
                        .font(.subheadline.weight(.semibold))
                    if let temporaryHomeLabel {
                        Text(temporaryHomeLabel)
                            .font(.caption2)
                            .opacity(0.85)
                            .lineLimit(1)
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.green.gradient, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(temporaryHomeLabel.map { Text("Take me home to \($0)") } ?? Text("Take me home"))
    }
}

#Preview {
    VStack(spacing: 16) {
        TakeMeHomeButton {}
        TakeMeHomeButton(temporaryHomeLabel: "Anna's place") {}
    }
    .padding()
}
