import SwiftUI

enum IncidentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case stalking = "Being Followed / Stalked"
    case assault = "Physical Assault / Fight"
    case harassment = "Harassment / Catcalling"
    case transitHazard = "Subway & Transit Danger"
    case poorLighting = "Dark / Broken Lighting"
    case drinkSpiking = "Drink Spiking / Bar Alert"
    case suspiciousPresence = "Suspicious Loitering / Group"
    case other = "Other Safety Concern"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .stalking:
            return "figure.walk.motion"
        case .assault:
            return "hand.raised.fill"
        case .harassment:
            return "megaphone.fill"
        case .transitHazard:
            return "tram.fill"
        case .poorLighting:
            return "lightbulb.slash.fill"
        case .drinkSpiking:
            return "wineglass.fill"
        case .suspiciousPresence:
            return "person.3.fill"
        case .other:
            return "shield.lefthalf.filled"
        }
    }

    var color: Color {
        switch self {
        case .stalking:
            return .purple
        case .assault:
            return .red
        case .harassment:
            return .orange
        case .transitHazard:
            return .yellow
        case .poorLighting:
            return .indigo
        case .drinkSpiking:
            return .pink
        case .suspiciousPresence:
            return .teal
        case .other:
            return .gray
        }
    }
}
