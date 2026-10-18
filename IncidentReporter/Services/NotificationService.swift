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
}
