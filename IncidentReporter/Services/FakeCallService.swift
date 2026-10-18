import Foundation
import AVFoundation
import AudioToolbox
import Observation

@Observable
final class FakeCallService: NSObject, @unchecked Sendable, AVSpeechSynthesizerDelegate {
    static let shared = FakeCallService()

    var isCallActive = false
    var isIncomingRinging = false
    var callerName: String = "Emma"
    var durationSeconds: Int = 0

    private var speechSynthesizer = AVSpeechSynthesizer()
    private var timer: Timer?
    private var scheduledTask: Task<Void, Never>?

    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    func scheduleCall(delaySeconds: Int, caller: String = "Emma") {
        callerName = caller
        scheduledTask?.cancel()

        if delaySeconds <= 0 {
            triggerIncomingCall()
            return
        }

        scheduledTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
            if !Task.isCancelled {
                self.triggerIncomingCall()
            }
        }
    }

    func cancelScheduledCall() {
        scheduledTask?.cancel()
        scheduledTask = nil
        isIncomingRinging = false
        isCallActive = false
        stopTimer()
    }

    private func triggerIncomingCall() {
        isIncomingRinging = true
        isCallActive = false
        durationSeconds = 0
        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }

    func answerCall(language: String = "en") {
        isIncomingRinging = false
        isCallActive = true
        durationSeconds = 0

        startTimer()
        configureAudioSessionForCall()
        speakConversationalPrompt(language: language)
    }

    func endCall() {
        isIncomingRinging = false
        isCallActive = false
        speechSynthesizer.stopSpeaking(at: .immediate)
        stopTimer()
        resetAudioSession()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.durationSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        durationSeconds = 0
    }

    private func configureAudioSessionForCall() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP])
        try? audioSession.setActive(true)
    }

    private func resetAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func speakConversationalPrompt(language: String) {
        let phrase: String
        let voiceLang: String

        if language == "sv" {
            phrase = "Hej! Var är du någonstans? Jag står precis här utanför och väntar på dig. Kom nu så går vi tillsammans."
            voiceLang = "sv-SE"
        } else {
            phrase = "Hey! Where are you? I'm standing right outside waiting for you. Come over now, let's head home."
            voiceLang = "en-US"
        }

        let utterance = AVSpeechUtterance(string: phrase)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLang)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.05

        speechSynthesizer.speak(utterance)
    }
}
