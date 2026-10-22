import Foundation
import AppIntents
import SwiftUI
import Observation

/// Coordinates deep-link and hardware trigger actions (Action Button, Shortcuts, Shake Gesture) across the UI.
@Observable
final class QuickActionCoordinator: @unchecked Sendable {
    static let shared = QuickActionCoordinator()

    var shouldPresentReportSheet = false
    var shouldPresentSafetyTimerSheet = false

    private init() {}
}

// MARK: - 1. Discreet Fake Call Intent

struct TriggerFakeCallIntent: AppIntent {
    static let title: LocalizedStringResource = "Trigger Discreet Fake Call"
    static let description = IntentDescription(
        "Immediately triggers an incoming safety phone call screen in IncidentTracker."
    )
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let caller = UserDefaults.standard.string(forKey: "fakeCallerName") ?? "Emma"
        FakeCallService.shared.scheduleCall(delaySeconds: 0, caller: caller)
        return .result()
    }
}

// MARK: - 2. Start Safety Timer Intent

struct StartSafetyTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start 20-Minute Safety Timer"
    static let description = IntentDescription(
        "Starts a 20-minute Safety Walk countdown timer with check-in reminders."
    )
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        SafetyTimerService.shared.startTimer(minutes: 20, destination: "Home")
        return .result()
    }
}

// MARK: - 3. Quick Report Danger Intent

struct QuickReportDangerIntent: AppIntent {
    static let title: LocalizedStringResource = "Report Safety Incident"
    static let description = IntentDescription(
        "Opens IncidentTracker directly to the Report Safety Alert screen with your current location."
    )
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActionCoordinator.shared.shouldPresentReportSheet = true
        return .result()
    }
}

// MARK: - App Shortcuts Provider (Action Button / Siri / Shortcuts)

struct IncidentReporterShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TriggerFakeCallIntent(),
            phrases: [
                "Trigger fake call in \(.applicationName)",
                "Call me now with \(.applicationName)"
            ],
            shortTitle: "Discreet Fake Call",
            systemImageName: "phone.badge.waveform.fill"
        )
        AppShortcut(
            intent: StartSafetyTimerIntent(),
            phrases: [
                "Start safety timer in \(.applicationName)",
                "Start safety walk in \(.applicationName)"
            ],
            shortTitle: "Start Safety Timer",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: QuickReportDangerIntent(),
            phrases: [
                "Report danger in \(.applicationName)",
                "Report safety alert in \(.applicationName)"
            ],
            shortTitle: "Report Danger",
            systemImageName: "exclamationmark.triangle.fill"
        )
    }
}
