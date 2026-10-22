import SwiftUI

/// A reusable card component for playing back an audio voice memo attached to an incident report.
struct VoiceMemoPlayerCard: View {
    let isPlaying: Bool
    let progress: Double
    let currentTimeText: String
    let totalDurationText: String
    let errorMessage: String?
    let onTogglePlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.badge.mic")
                    .foregroundStyle(.indigo)
                Text("Attached Voice Memo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(currentTimeText) / \(totalDurationText)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button(action: onTogglePlay) {
                    Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.indigo, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isPlaying ? "Stop voice memo" : "Play voice memo")

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.indigo.opacity(0.18))
                            .frame(height: 8)

                        Capsule()
                            .fill(Color.indigo)
                            .frame(width: max(8, geo.size.width * progress), height: 8)
                            .animation(.linear(duration: 0.1), value: progress)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 24)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.indigo.opacity(0.22), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        VoiceMemoPlayerCard(
            isPlaying: false,
            progress: 0.0,
            currentTimeText: "0:00",
            totalDurationText: "0:18",
            errorMessage: nil,
            onTogglePlay: {}
        )
        VoiceMemoPlayerCard(
            isPlaying: true,
            progress: 0.45,
            currentTimeText: "0:08",
            totalDurationText: "0:18",
            errorMessage: nil,
            onTogglePlay: {}
        )
    }
    .padding()
}
