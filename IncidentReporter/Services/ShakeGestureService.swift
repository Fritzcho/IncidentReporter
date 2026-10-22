import SwiftUI
import UIKit

/// Configurable action executed when the user firmly shakes their iPhone.
enum ShakeTriggerAction: String, CaseIterable, Identifiable {
    case disabled = "Disabled"
    case fakeCall = "Discreet Fake Call"
    case reportDanger = "Open Report Alert"
    case startSafetyTimer = "Start 20m Safety Timer"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .disabled:
            return "hand.raised.slash.fill"
        case .fakeCall:
            return "phone.badge.waveform.fill"
        case .reportDanger:
            return "exclamationmark.triangle.fill"
        case .startSafetyTimer:
            return "timer"
        }
    }
}

extension Notification.Name {
    static let deviceDidShakeNotification = Notification.Name("IncidentReporter.deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShakeNotification, object: nil)
        }
    }
}

/// View modifier that listens for device shake events and triggers the user's configured safety action.
struct ShakeTriggerModifier: ViewModifier {
    let onShake: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
                onShake()
            }
    }
}

extension View {
    func onDeviceShake(perform action: @escaping () -> Void) -> some View {
        modifier(ShakeTriggerModifier(onShake: action))
    }
}
