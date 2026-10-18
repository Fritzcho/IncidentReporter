import SwiftUI

enum IncidentSeverity: String, Codable, CaseIterable, Identifiable, Sendable {
    case low = "Caution"
    case medium = "Elevated Risk"
    case high = "High Danger"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}
