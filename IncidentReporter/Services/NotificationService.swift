import Foundation
import UserNotifications
import CoreLocation

final class NotificationService: Sendable {
    static let shared = NotificationService()

    private init() {}

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            print("Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }

    func scheduleProximityNotification(for incident: Incident, distance: CLLocationDistance) {
        let content = UNMutableNotificationContent()
        content.title = "Safety Alert Ahead: \(incident.category.rawValue)"
        
        let roundedDistance = Int(distance)
        content.body = "\(incident.title) reported ~\(roundedDistance)m from your path. Stay vigilant and consider taking a well-lit alternate route."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "incident-proximity-\(incident.id.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Failed to deliver proximity notification: \(error.localizedDescription)")
            }
        }
    }

    func scheduleSafetyTimerNotifications(durationSeconds: TimeInterval, destinationNote: String) {
        cancelSafetyTimerNotifications()

        let center = UNUserNotificationCenter.current()

        // 1. Pre-expiry check-in warning (2 minutes before expiry, or halfway if shorter)
        let warningOffset = durationSeconds > 180 ? (durationSeconds - 120) : max(5, durationSeconds * 0.5)
        let warningContent = UNMutableNotificationContent()
        warningContent.title = "Safety Check-in Reminder"
        warningContent.body = destinationNote.isEmpty
            ? "Your safety timer expires soon. Open IncidentTracker to confirm you are safe."
            : "Arrived at \(destinationNote)? Open IncidentTracker to check in before your timer expires."
        warningContent.sound = .default

        let warningTrigger = UNTimeIntervalNotificationTrigger(timeInterval: warningOffset, repeats: false)
        let warningRequest = UNNotificationRequest(
            identifier: "safety-timer-warning",
            content: warningContent,
            trigger: warningTrigger
        )
        center.add(warningRequest)

        // 2. Expiration escalation alert
        let expiredContent = UNMutableNotificationContent()
        expiredContent.title = "⚠️ Safety Timer Expired"
        expiredContent.body = "You missed your safety check-in deadline. Tap immediately to disarm or send an emergency alert to your contact."
        expiredContent.sound = .defaultCritical

        let expiredTrigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, durationSeconds), repeats: false)
        let expiredRequest = UNNotificationRequest(
            identifier: "safety-timer-expired",
            content: expiredContent,
            trigger: expiredTrigger
        )
        center.add(expiredRequest)
    }

    func cancelSafetyTimerNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["safety-timer-warning", "safety-timer-expired"]
        )
    }
}
