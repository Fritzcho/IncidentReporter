import SwiftUI

struct FakeCallView: View {
    @Bindable var callService: FakeCallService = FakeCallService.shared
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @Environment(\.dismiss) private var dismiss

    var formattedDuration: String {
        let mins = callService.durationSeconds / 60
        let secs = callService.durationSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var body: some View {
        ZStack {
            // Realistic dark blur / night background
            LinearGradient(
                colors: [Color.black, Color(white: 0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if callService.isIncomingRinging {
                incomingCallScreen
            } else {
                activeCallScreen
            }
        }
    }

    // MARK: - Incoming Call Screen
    private var incomingCallScreen: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            VStack(spacing: 8) {
                Text(callService.callerName)
                    .font(.system(size: 38, weight: .semibold, design: .default))
                    .foregroundStyle(.white)

                Text("Incoming Call • Mobile")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Call Action Buttons (Remind Me / Message)
            HStack(spacing: 80) {
                VStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                    Text("Remind Me")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 6) {
                    Image(systemName: "message.fill")
                        .font(.title2)
                    Text("Message")
                        .font(.caption2)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.bottom, 40)

            // Decline & Accept Buttons
            HStack(spacing: 100) {
                // Decline
                VStack(spacing: 8) {
                    Button {
                        callService.endCall()
                        dismiss()
                    } label: {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    Text("Decline")
                        .font(.caption)
                        .foregroundStyle(.white)
                }

                // Accept
                VStack(spacing: 8) {
                    Button {
                        callService.answerCall(language: appLanguage)
                    } label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Color.green)
                            .clipShape(Circle())
                    }
                    Text("Accept")
                        .font(.caption)
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 60)
        }
    }

    // MARK: - Active Call Screen
    private var activeCallScreen: some View {
        VStack(spacing: 30) {
            Spacer().frame(height: 60)

            VStack(spacing: 8) {
                Text(callService.callerName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)

                Text(formattedDuration)
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            // In-Call Grid Icons
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 30), count: 3), spacing: 28) {
                callIconButton(systemName: "mic.slash.fill", label: "mute")
                callIconButton(systemName: "circle.grid.3x3.fill", label: "keypad")
                callIconButton(systemName: "speaker.wave.3.fill", label: "audio")
                callIconButton(systemName: "plus", label: "add call")
                callIconButton(systemName: "video.fill", label: "FaceTime")
                callIconButton(systemName: "person.crop.circle", label: "contacts")
            }
            .padding(.horizontal, 36)

            Spacer()

            // End Call Button
            Button {
                callService.endCall()
                dismiss()
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .padding(.bottom, 60)
        }
    }

    private func callIconButton(systemName: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(Color.white.opacity(0.16))
                .clipShape(Circle())

            Text(label)
                .font(.caption)
                .foregroundStyle(.white)
        }
    }
}
