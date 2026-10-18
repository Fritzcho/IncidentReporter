import SwiftUI

struct FakeCallLauncherSheet: View {
    @Bindable var callService: FakeCallService = FakeCallService.shared
    @Environment(\.dismiss) private var dismiss

    @AppStorage("fakeCallerName") private var callerName: String = "Emma"
    @State private var selectedDelay: Int = 0 // 0, 10, 30 seconds
    @State private var isCountdownActive = false
    @State private var remainingSeconds = 0
    @State private var timer: Timer?

    private let presetNames = ["Emma", "Dad", "Mom", "Marcus", "Alex"]

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Discreet Safety Call"),
                    footer: Text("Triggers a realistic incoming call screen. When answered, a voice speaks through your earpiece so you appear to be in active conversation.")
                ) {
                    Picker("Caller Name", selection: $callerName) {
                        ForEach(presetNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    TextField("Or enter custom name...", text: $callerName)
                }

                Section(header: Text("Timing Delay")) {
                    Picker("Delay", selection: $selectedDelay) {
                        Text("Immediately").tag(0)
                        Text("In 10 seconds").tag(10)
                        Text("In 30 seconds").tag(30)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    if isCountdownActive {
                        VStack(spacing: 8) {
                            Text("Incoming call in \(remainingSeconds)s...")
                                .font(.headline)
                                .foregroundStyle(.purple)

                            Button("Cancel Scheduled Call", role: .destructive) {
                                cancelCountdown()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            startCallSequence()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "phone.fill")
                                Text(selectedDelay == 0 ? "Call Me Now" : "Schedule Call (\(selectedDelay)s)")
                                Spacer()
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Color.purple)
                    }
                }
            }
            .navigationTitle("Discreet Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelCountdown()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .fraction(0.55)])
    }

    private func startCallSequence() {
        if selectedDelay == 0 {
            callService.scheduleCall(delaySeconds: 0, caller: callerName)
            dismiss()
        } else {
            isCountdownActive = true
            remainingSeconds = selectedDelay
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if remainingSeconds > 1 {
                    remainingSeconds -= 1
                } else {
                    timer?.invalidate()
                    timer = nil
                    isCountdownActive = false
                    callService.scheduleCall(delaySeconds: 0, caller: callerName)
                    dismiss()
                }
            }
        }
    }

    private func cancelCountdown() {
        timer?.invalidate()
        timer = nil
        isCountdownActive = false
        callService.cancelScheduledCall()
    }
}
