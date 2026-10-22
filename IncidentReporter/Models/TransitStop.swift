import Foundation
import CoreLocation
import SwiftUI

/// SL public transport modes, in pin and display priority order.
nonisolated enum TransitMode: String, CaseIterable, Identifiable, Sendable {
    case metro = "METRO"
    /// Pendeltåg. Roslagsbanan and Saltsjöbanan are reported by SL as TRAM and are not included.
    case train = "TRAIN"
    /// Spårväg City, Tvärbanan, Lidingöbanan, Nockebybanan, Roslagsbanan and Saltsjöbanan.
    case tram = "TRAM"
    case bus = "BUS"
    /// Pendelbåt and Waxholmsbolaget ferries.
    case ship = "SHIP"

    var id: String { rawValue }

    /// Modes the map resolves a nearest stop for automatically. Trams and boats are still shown
    /// when the user looks up a specific stop.
    static let nearbyModes: [TransitMode] = [.metro, .train, .bus]

    var title: LocalizedStringKey {
        switch self {
        case .metro: return "Subway"
        case .train: return "Commuter train"
        case .tram: return "Tram & light rail"
        case .bus: return "Bus"
        case .ship: return "Boat"
        }
    }

    var systemImage: String {
        switch self {
        case .metro: return "tram.fill.tunnel"
        case .train: return "lightrail.fill"
        case .tram: return "tram.fill"
        case .bus: return "bus.fill"
        case .ship: return "ferry.fill"
        }
    }

    var color: Color {
        switch self {
        case .metro: return .blue
        case .train: return .pink
        case .tram: return .orange
        case .bus: return .red
        case .ship: return .teal
        }
    }
}

/// A single upcoming departure from a stop.
nonisolated struct TransitDeparture: Identifiable, Hashable, Sendable {
    let id: String
    let mode: TransitMode
    let line: String
    let destination: String
    let scheduled: Date
    let expected: Date
    /// Platform / stop point designation (e.g. "2" or "C")
    let platform: String?

    /// Minutes the departure is running behind its timetable.
    var delayMinutes: Int {
        Int(expected.timeIntervalSince(scheduled) / 60)
    }
}

/// Whether a mode is currently running at a stop, derived from its upcoming departures.
nonisolated enum TransitServiceStatus: Hashable, Sendable {
    /// Departures are leaving within the next hour. `lastDeparture` is the final one before
    /// the overnight break, when that break starts within `completeDataWindow`.
    case running(next: TransitDeparture, lastDeparture: TransitDeparture?)
    /// No departures in the next hour; service resumes with `next`.
    case closed(next: TransitDeparture)
    /// No departures at all in the forecast window.
    case noService

    /// A gap longer than this between departures counts as the service being closed.
    static let serviceBreak: TimeInterval = 60 * 60

    /// SL's departures API only lists every departure for roughly the next hour; further ahead it
    /// returns a sparse sample (e.g. 19:27, 19:33, then 00:39 at Stockholms södra). Gaps that start
    /// beyond this window are missing data, not the end of service.
    static let completeDataWindow: TimeInterval = 60 * 60

    init(departures: [TransitDeparture], now: Date = .now) {
        let upcoming = departures
            .filter { $0.expected >= now.addingTimeInterval(-30) }
            .sorted { $0.expected < $1.expected }

        guard let next = upcoming.first else {
            self = .noService
            return
        }
        guard next.expected.timeIntervalSince(now) <= Self.serviceBreak else {
            self = .closed(next: next)
            return
        }

        // Look for the overnight break only where the data is complete
        let windowEnd = now.addingTimeInterval(Self.completeDataWindow)
        var last: TransitDeparture?
        for (index, current) in upcoming.enumerated() {
            guard current.expected <= windowEnd else { break }
            let following = upcoming.indices.contains(index + 1) ? upcoming[index + 1] : nil
            if let following, following.expected.timeIntervalSince(current.expected) <= Self.serviceBreak {
                continue
            }
            last = current
            break
        }
        self = .running(next: next, lastDeparture: last)
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
}

/// An SL stop (site) with live departures for the transit modes it serves.
nonisolated struct TransitStop: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let coordinate: CLLocationCoordinate2D
    /// The modes this stop was picked as nearest for, in display order.
    let modes: [TransitMode]
    let departures: [TransitDeparture]
    let fetchedAt: Date

    /// The mode used for the map pin (subway, then commuter train, then bus).
    var primaryMode: TransitMode { modes.first ?? .bus }

    func departures(for mode: TransitMode) -> [TransitDeparture] {
        departures.filter { $0.mode == mode }
    }

    func status(for mode: TransitMode, now: Date = .now) -> TransitServiceStatus {
        TransitServiceStatus(departures: departures(for: mode), now: now)
    }

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        location?.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    static func == (lhs: TransitStop, rhs: TransitStop) -> Bool {
        lhs.id == rhs.id && lhs.fetchedAt == rhs.fetchedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(fetchedAt)
    }
}

/// A stop from SL's stop register, used for searching before departures are loaded.
nonisolated struct TransitStopSummary: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    /// Disambiguating area for stops that share a name (e.g. "Runmarö").
    let note: String?
    let coordinate: CLLocationCoordinate2D

    func distance(from location: CLLocation?) -> CLLocationDistance? {
        location?.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    static func == (lhs: TransitStopSummary, rhs: TransitStopSummary) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
