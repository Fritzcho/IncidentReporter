import SwiftUI

/// An input component for recording, previewing, and deleting a hands-free voice memo when submitting an incident report.
struct VoiceMemoRecorderInputView: View {
    let isRecording: Bool
    let isPlaying: Bool
    let hasRecordedMemo: Bool
    let durationText: String
    let audioLevel: Float
    let errorMessage: String?
    let onToggleRecord: () -> Void
    let onTogglePreviewPlay: () -> Void
    let onDeleteMemo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isRecording {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)
                        .opacity(0.9)

                    Text("Recording voice memo...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)

                    Spacer()

                    Text(durationText)
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.red)
                }

                // Dynamic level bar indicator
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.red.opacity(0.15))
                            .frame(height: 6)

                        Capsule()
                            .fill(Color.red)
                            .frame(width: max(12, geo.size.width * CGFloat(audioLevel)), height: 6)
                            .animation(.easeOut(duration: 0.1), value: audioLevel)
                    }
                }
                .frame(height: 8)

                Button(action: onToggleRecord) {
                    HStack {
                        Spacer()
                        Image(systemName: "stop.circle.fill")
                        Text("Stop Recording")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else if hasRecordedMemo {
                HStack(spacing: 12) {
                    Button(action: onTogglePreviewPlay) {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.indigo)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPlaying ? "Stop voice memo preview" : "Play voice memo preview")

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice Memo Attached")
                            .font(.subheadline.weight(.semibold))
                        Text("Duration: \(durationText)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(role: .destructive, action: onDeleteMemo) {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete recorded voice memo")
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hands-Free Voice Note")
                            .font(.subheadline.weight(.medium))
                        Text("Record up to 60s instead of typing while walking")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onToggleRecord) {
                        Label("Record", systemImage: "mic.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
                .padding(.vertical, 2)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    Form {
        Section("Idle State") {
            VoiceMemoRecorderInputView(
                isRecording: false,
                isPlaying: false,
                hasRecordedMemo: false,
                durationText: "0:00",
                audioLevel: 0.2,
                errorMessage: nil,
                onToggleRecord: {},
                onTogglePreviewPlay: {},
                onDeleteMemo: {}
            )
        }
        Section("Recording State") {
            VoiceMemoRecorderInputView(
                isRecording: true,
                isPlaying: false,
                hasRecordedMemo: false,
                durationText: "0:12",
                audioLevel: 0.65,
                errorMessage: nil,
                onToggleRecord: {},
                onTogglePreviewPlay: {},
                onDeleteMemo: {}
            )
        }
        Section("Recorded State") {
            VoiceMemoRecorderInputView(
                isRecording: false,
                isPlaying: false,
                hasRecordedMemo: true,
                durationText: "0:19",
                audioLevel: 0.2,
                errorMessage: nil,
                onToggleRecord: {},
                onTogglePreviewPlay: {},
                onDeleteMemo: {}
            )
        }
    }
}
