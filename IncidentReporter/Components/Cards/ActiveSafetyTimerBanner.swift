import SwiftUI

/// A floating top banner displayed on the map when a Safety Timer is running or escalated.
struct ActiveSafetyTimerBanner: View {
    let formattedTime: String
    let destinationNote: String
    let isExpiringSoon: Bool
    let isEscalated: Bool
    let onAddFiveMinutes: () -> Void
    let onCheckInSafe: () -> Void
    let onOpenDetails: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: isEscalated ? "exclamationmark.shield.fill" : "timer")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(badgeBackground, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(isEscalated ? "Safety Timer Expired!" : "Safety Walk Active")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)

                        if !destinationNote.isEmpty {
                            Text("• \(destinationNote)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    if isEscalated {
                        Text("Check in immediately or alert your emergency contact.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        Text("Check-in countdown: \(formattedTime)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(isExpiringSoon ? .orange : .secondary)
                    }
                }

                Spacer()

                if !isEscalated {
                    Text(formattedTime)
                        .font(.headline.monospacedDigit().bold())
                        .foregroundStyle(isExpiringSoon ? .orange : .teal)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpenDetails)

            HStack(spacing: 10) {
                if !isEscalated {
                    Button(action: onAddFiveMinutes) {
                        Label("+5 min", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.bordered)
                    .tint(.teal)
                }

                Button(action: onCheckInSafe) {
                    Label(isEscalated ? "Disarm Alarm" : "I'm Safe", systemImage: "faceid")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.borderedProminent)
                .tint(isEscalated ? .red : .green)
            }
        }
        .padding(14)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: isEscalated ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 10, y: 4)
        .padding(.horizontal, 14)
    }

    private var badgeBackground: Color {
        if isEscalated {
            return .red
        } else if isExpiringSoon {
            return .orange
        } else {
            return .teal
        }
    }

    private var borderColor: Color {
        if isEscalated {
            return .red
        } else if isExpiringSoon {
            return .orange.opacity(0.6)
        } else {
            return .teal.opacity(0.35)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ActiveSafetyTimerBanner(
            formattedTime: "14:25",
            destinationNote: "Skanstull T-bana",
            isExpiringSoon: false,
            isEscalated: false,
            onAddFiveMinutes: {},
            onCheckInSafe: {},
            onOpenDetails: {}
        )

        ActiveSafetyTimerBanner(
            formattedTime: "00:00",
            destinationNote: "Home",
            isExpiringSoon: true,
            isEscalated: true,
            onAddFiveMinutes: {},
            onCheckInSafe: {},
            onOpenDetails: {}
        )
    }
    .padding(.vertical)
}
