import Foundation
import LocalAuthentication
import AudioToolbox
import CoreLocation
import UIKit
import Observation

/// Manages the Safety Timer ("Walk With Me" check-in deadline), biometric disarming, and emergency escalation.
@Observable
final class SafetyTimerService: @unchecked Sendable {
    static let shared = SafetyTimerService()

    enum State: Equatable {
        case idle
        case running
        case expiringSoon
        case escalated
    }

    var state: State = .idle
    var remainingSeconds: Int = 0
    var totalDurationSeconds: Int = 0
    var destinationNote: String = ""
    var endTime: Date? = nil
    var authErrorMessage: String? = nil

    private var timer: Timer?
    private var alarmTimer: Timer?

    private let endTimeKey = "safetyTimer.endTime"
    private let totalDurationKey = "safetyTimer.totalDuration"
    private let destinationKey = "safetyTimer.destination"

    var isActive: Bool {
        state != .idle
    }

    var formattedRemainingTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var progress: Double {
        guard totalDurationSeconds > 0 else { return 0 }
        let elapsed = Double(totalDurationSeconds - remainingSeconds)
        return min(1.0, max(0.0, elapsed / Double(totalDurationSeconds)))
    }

    private init() {
        restorePersistedTimerIfNeeded()
    }

    func startTimer(minutes: Int, destination: String = "") {
        let seconds = max(60, minutes * 60)
        let targetDate = Date().addingTimeInterval(TimeInterval(seconds))

        totalDurationSeconds = seconds
        remainingSeconds = seconds
        destinationNote = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        endTime = targetDate
        authErrorMessage = nil
        state = .running

        UserDefaults.standard.set(targetDate.timeIntervalSince1970, forKey: endTimeKey)
        UserDefaults.standard.set(seconds, forKey: totalDurationKey)
        UserDefaults.standard.set(destinationNote, forKey: destinationKey)

        NotificationService.shared.scheduleSafetyTimerNotifications(
            durationSeconds: TimeInterval(seconds),
            destinationNote: destinationNote
        )

        startTicking()
    }

    func addFiveMinutes() {
        guard let currentEnd = endTime, state == .running || state == .expiringSoon else { return }
        let newEnd = currentEnd.addingTimeInterval(300)
        endTime = newEnd
        totalDurationSeconds += 300
        remainingSeconds = max(0, Int(newEnd.timeIntervalSinceNow))
        state = remainingSeconds <= 120 ? .expiringSoon : .running

        UserDefaults.standard.set(newEnd.timeIntervalSince1970, forKey: endTimeKey)
        UserDefaults.standard.set(totalDurationSeconds, forKey: totalDurationKey)

        NotificationService.shared.scheduleSafetyTimerNotifications(
            durationSeconds: TimeInterval(remainingSeconds),
            destinationNote: destinationNote
        )
    }

    /// Disarms the safety timer using Face ID / Touch ID or device passcode fallback.
    func disarmWithBiometrics(completion: @escaping (Bool) -> Void = { _ in }) {
        let context = LAContext()
        var error: NSError?
        let reason = "Confirm you have arrived safely to disarm the Safety Timer."

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, evalError in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if success {
                        self.forceDisarm()
                        completion(true)
                    } else {
                        self.authErrorMessage = evalError?.localizedDescription ?? "Authentication failed."
                        completion(false)
                    }
                }
            }
        } else {
            // Simulator or device without passcode configured: allow direct disarm
            forceDisarm()
            completion(true)
        }
    }

    func forceDisarm() {
        timer?.invalidate()
        timer = nil
        stopAudibleAlarm()
        state = .idle
        remainingSeconds = 0
        totalDurationSeconds = 0
        endTime = nil
        authErrorMessage = nil

        UserDefaults.standard.removeObject(forKey: endTimeKey)
        UserDefaults.standard.removeObject(forKey: totalDurationKey)
        UserDefaults.standard.removeObject(forKey: destinationKey)

        NotificationService.shared.cancelSafetyTimerNotifications()
    }

    func triggerEscalationNow() {
        timer?.invalidate()
        timer = nil
        remainingSeconds = 0
        state = .escalated
        startAudibleAlarm()
    }

    /// Constructs and opens an SMS URL to the user's emergency contact with current coordinates.
    func sendEmergencySMS(userLocation: CLLocation?) {
        let phone = UserDefaults.standard.string(forKey: "emergencyContactPhone") ?? ""
        let contactName = UserDefaults.standard.string(forKey: "emergencyContactName") ?? "Trusted Contact"
        let cleanedPhone = phone.components(separatedBy: CharacterSet(charactersIn: "+0123456789").inverted).joined()

        var message = "SOS Safety Alert from IncidentTracker: My safety walk timer expired without check-in."
        if !destinationNote.isEmpty {
            message += " Heading to: \(destinationNote)."
        }
        if let loc = userLocation {
            let lat = String(format: "%.5f", loc.coordinate.latitude)
            let lon = String(format: "%.5f", loc.coordinate.longitude)
            message += " Last known GPS location: https://maps.apple.com/?ll=\(lat),\(lon)"
        } else {
            message += " Please call or check on me (\(contactName))."
        }

        let encodedBody = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = cleanedPhone.isEmpty ? "sms:&body=\(encodedBody)" : "sms:\(cleanedPhone)&body=\(encodedBody)"

        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Private Helpers

    private func restorePersistedTimerIfNeeded() {
        let savedTimestamp = UserDefaults.standard.double(forKey: endTimeKey)
        guard savedTimestamp > 0 else { return }

        let targetDate = Date(timeIntervalSince1970: savedTimestamp)
        let savedTotal = UserDefaults.standard.integer(forKey: totalDurationKey)
        let savedDest = UserDefaults.standard.string(forKey: destinationKey) ?? ""

        endTime = targetDate
        totalDurationSeconds = max(60, savedTotal)
        destinationNote = savedDest

        let diff = Int(targetDate.timeIntervalSinceNow)
        if diff > 0 {
            remainingSeconds = diff
            state = diff <= 120 ? .expiringSoon : .running
            startTicking()
        } else {
            remainingSeconds = 0
            state = .escalated
            startAudibleAlarm()
        }
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let endTime else {
            forceDisarm()
            return
        }

        let remaining = Int(ceil(endTime.timeIntervalSinceNow))
        if remaining > 0 {
            remainingSeconds = remaining
            state = remaining <= 120 ? .expiringSoon : .running
        } else {
            triggerEscalationNow()
        }
    }

    private func startAudibleAlarm() {
        stopAudibleAlarm()
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
    }

    func stopAudibleAlarm() {
        alarmTimer?.invalidate()
        alarmTimer = nil
    }
}
