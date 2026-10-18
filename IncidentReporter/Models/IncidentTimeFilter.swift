import Foundation

enum IncidentTimeFilter: String, CaseIterable, Identifiable {
    case fourHours = "4h"
    case twelveHours = "12h"
    case twentyFourHours = "24h"
    case week = "Week"

    var id: String { rawValue }

    var hours: Double {
        switch self {
        case .fourHours: return 4
        case .twelveHours: return 12
        case .twentyFourHours: return 24
        case .week: return 168
        }
    }

    var hoursOffset: Int {
        -Int(hours)
    }

    var displayName: String {
        switch self {
        case .fourHours:
            return "4 Hours"
        case .twelveHours:
            return "12 Hours"
        case .twentyFourHours:
            return "24 Hours"
        case .week:
            return "Week"
        }
    }

    var cutoffDate: Date? {
        Calendar.current.date(byAdding: .hour, value: hoursOffset, to: Date())
    }
}
enum IncidentDecayStatus: String, Sendable {
    case recent = "Recent"
    case active = "Active"
    case aging = "Aging"
    case expired = "Expired"

    var opacity: Double {
        switch self {
        case .recent:
            return 1.0
        case .active:
            return 0.9
        case .aging:
            return 0.65
        case .expired:
            return 0.4
        }
    }

    var icon: String {
        switch self {
        case .recent:
            return "flame.fill"
        case .active:
            return "clock.fill"
        case .aging:
            return "clock.arrow.circlepath"
        case .expired:
            return "archivebox.fill"
        }
    }
}
