import SwiftUI
import CoreLocation

/// Sheet for starting, monitoring, or disarming a Safety Walk countdown timer.
struct SafetyTimerSheet: View {
    @Bindable var timerService: SafetyTimerService = SafetyTimerService.shared
    let userLocation: CLLocation?
    @Environment(\.dismiss) private var dismiss

    @AppStorage("emergencyContactName") private var contactName: String = "Emma"
    @AppStorage("emergencyContactPhone") private var contactPhone: String = ""

    @State private var selectedMinutes: Int = 20
    @State private var destinationInput: String = ""

    private let minutePresets = [10, 20, 30, 45]

    var body: some View {
        NavigationStack {
            Form {
                if timerService.isActive {
                    activeTimerSections
                } else {
                    setupTimerSections
                }
            }
            .navigationTitle("Safety Walk Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Setup Sections (Idle)

    @ViewBuilder
    private var setupTimerSections: some View {
        Section(
            header: Text("Check-In Duration"),
            footer: Text("If you don't confirm you are safe before the timer expires, an audible alarm sounds and an SOS message with your GPS coordinates can be sent to your trusted contact.")
        ) {
            Picker("Duration", selection: $selectedMinutes) {
                ForEach(minutePresets, id: \.self) { mins in
                    Text("\(mins) min").tag(mins)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.teal)
                    .frame(width: 24)
                TextField("Destination note (e.g. Home, Odenplan)", text: $destinationInput)
            }
        }

        Section(
            header: Text("Trusted Guardian Contact"),
            footer: Text("Used to pre-fill an emergency SMS with your live Apple Maps coordinates if the timer expires.")
        ) {
            EmergencyContactInputView(
                contactName: $contactName,
                contactPhone: $contactPhone
            )
        }

        Section {
            Button {
                timerService.startTimer(minutes: selectedMinutes, destination: destinationInput)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "figure.walk.motion")
                    Text("Start \(selectedMinutes)-Minute Safety Timer")
                    Spacer()
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.teal)
        }
    }

    // MARK: - Active / Escalated Sections

    @ViewBuilder
    private var activeTimerSections: some View {
        Section {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 10)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: 1.0 - timerService.progress)
                        .stroke(
                            timerService.state == .escalated ? Color.red : (timerService.state == .expiringSoon ? Color.orange : Color.teal),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 140, height: 140)
                        .animation(.linear(duration: 0.4), value: timerService.progress)

                    VStack(spacing: 4) {
                        if timerService.state == .escalated {
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                                .font(.title)
                                .foregroundStyle(.red)
                            Text("EXPIRED")
                                .font(.caption.bold())
                                .foregroundStyle(.red)
                        } else {
                            Text(timerService.formattedRemainingTime)
                                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                            Text("Remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)

                if !timerService.destinationNote.isEmpty {
                    Label("Destination: \(timerService.destinationNote)", systemImage: "flag.checkered")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let authError = timerService.authErrorMessage {
                    Text(authError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }

        Section("Safety Actions") {
            Button {
                timerService.disarmWithBiometrics { success in
                    if success {
                        dismiss()
                    }
                }
            } label: {
                Label("I'm Safe — Disarm with Face ID", systemImage: "faceid")
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            if timerService.state != .escalated {
                Button {
                    timerService.addFiveMinutes()
                } label: {
                    Label("Add 5 Extra Minutes", systemImage: "plus.circle.fill")
                        .foregroundStyle(.teal)
                }
            }

            Button(role: .destructive) {
                timerService.sendEmergencySMS(userLocation: userLocation)
            } label: {
                Label(
                    contactName.isEmpty
                        ? "Send Emergency SOS SMS Now"
                        : "Send SOS SMS to \(contactName)",
                    systemImage: "message.badge.waveform.fill"
                )
                .font(.subheadline.weight(.semibold))
            }
        }
    }
}

#Preview {
    SafetyTimerSheet(userLocation: CLLocation(latitude: 59.3326, longitude: 18.0649))
}
