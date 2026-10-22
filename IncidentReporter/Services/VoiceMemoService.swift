import Foundation
import AVFoundation
import Observation

/// Service responsible for recording and playing back `.m4a` voice memos attached to incident reports.
@Observable
final class VoiceMemoService: NSObject, @unchecked Sendable, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    static let shared = VoiceMemoService()

    var isRecording = false
    var isPlaying = false
    var recordingDuration: TimeInterval = 0
    var playbackProgress: Double = 0
    var currentPlaybackTime: TimeInterval = 0
    var totalPlaybackDuration: TimeInterval = 0
    var audioLevel: Float = 0.15
    var errorMessage: String? = nil

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var meterTimer: Timer?
    private var activeRecordingFileName: String?

    private let maxRecordingSeconds: TimeInterval = 60.0

    override init() {
        super.init()
        ensureVoiceMemosDirectoryExists()
    }

    private var voiceMemosDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("VoiceMemos", isDirectory: true)
    }

    private func ensureVoiceMemosDirectoryExists() {
        try? FileManager.default.createDirectory(
            at: voiceMemosDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Recording

    func startRecording() async -> String? {
        stopPlayback()
        errorMessage = nil

        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            errorMessage = "Microphone permission is required to record a voice memo."
            return nil
        }

        ensureVoiceMemosDirectoryExists()
        let fileName = "memo-\(UUID().uuidString).m4a"
        let fileURL = voiceMemosDirectory.appendingPathComponent(fileName)

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.delegate = self
            recorder.isMeteringEnabled = true
            recorder.record(forDuration: maxRecordingSeconds)

            audioRecorder = recorder
            activeRecordingFileName = fileName
            recordingDuration = 0
            isRecording = true
            startMeterTimer()
            return fileName
        } catch {
            errorMessage = "Could not start recording: \(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    func stopRecording() -> (fileName: String?, duration: TimeInterval) {
        let finalDuration = audioRecorder?.currentTime ?? recordingDuration
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        stopMeterTimer()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (activeRecordingFileName, finalDuration)
    }

    func deleteVoiceMemo(fileName: String?) {
        stopPlayback()
        if isRecording {
            _ = stopRecording()
        }
        guard let fileName, !fileName.isEmpty else { return }
        let url = voiceMemosDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
        if activeRecordingFileName == fileName {
            activeRecordingFileName = nil
            recordingDuration = 0
        }
    }

    // MARK: - Playback

    func togglePlayback(for fileName: String) {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback(fileName: fileName)
        }
    }

    func startPlayback(fileName: String) {
        if isRecording {
            _ = stopRecording()
        }
        stopPlayback()
        errorMessage = nil

        let fileURL = voiceMemosDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            errorMessage = "Voice memo audio file not found."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: fileURL)
            player.delegate = self
            player.prepareToPlay()
            player.play()

            audioPlayer = player
            totalPlaybackDuration = max(0.1, player.duration)
            currentPlaybackTime = 0
            playbackProgress = 0
            isPlaying = true
            startMeterTimer()
        } catch {
            errorMessage = "Could not play voice memo: \(error.localizedDescription)"
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackProgress = 0
        currentPlaybackTime = 0
        stopMeterTimer()
    }

    // MARK: - Metering & Delegates

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeters()
            }
        }
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
        audioLevel = 0.15
    }

    private func updateMeters() {
        if let recorder = audioRecorder, recorder.isRecording {
            recorder.updateMeters()
            recordingDuration = recorder.currentTime
            let power = recorder.averagePower(forChannel: 0) // -160 to 0 dB
            let normalized = max(0.1, min(1.0, (power + 50.0) / 50.0))
            audioLevel = normalized
        } else if let player = audioPlayer, player.isPlaying {
            currentPlaybackTime = player.currentTime
            totalPlaybackDuration = max(0.1, player.duration)
            playbackProgress = min(1.0, max(0.0, player.currentTime / totalPlaybackDuration))
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            self.stopMeterTimer()
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playbackProgress = 0
            self.currentPlaybackTime = 0
            self.stopMeterTimer()
        }
    }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
