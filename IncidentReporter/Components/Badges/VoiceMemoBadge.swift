import SwiftUI

/// A compact pill badge indicating that an incident report includes an attached audio voice memo.
struct VoiceMemoBadge: View {
    let durationSeconds: Double?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "waveform")
                .font(.caption2.bold())
            if let durationSeconds, durationSeconds > 0 {
                Text(VoiceMemoService.formatDuration(durationSeconds))
                    .font(.caption2.monospacedDigit().weight(.semibold))
            } else {
                Text("Voice")
                    .font(.caption2.weight(.semibold))
            }
        }
        .foregroundStyle(.indigo)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.indigo.opacity(0.14), in: Capsule())
        .accessibilityLabel("Includes voice memo")
    }
}

#Preview {
    HStack(spacing: 12) {
        VoiceMemoBadge(durationSeconds: 18)
        VoiceMemoBadge(durationSeconds: nil)
    }
    .padding()
}
