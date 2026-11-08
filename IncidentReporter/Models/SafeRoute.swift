import Foundation
import MapKit

/// A reported danger the route planner tries to steer around: a user or police report, or an SL safety alert.
struct RouteDanger: Identifiable {
    let id: String
    let title: String
    let coordinate: CLLocationCoordinate2D
    let severity: IncidentSeverity
    let reportedAt: Date
    /// How careful the user wants routes to be (see `RouteCaution`); scales the penalty
    var weight: Double = 1

    init(incident: Incident, weight: Double = 1) {
        id = incident.id.uuidString
        title = incident.title
        coordinate = incident.coordinate
        severity = incident.severity
        reportedAt = incident.timestamp
        self.weight = weight
    }

    init(alert: TransitSafetyAlert, weight: Double = 1) {
        id = alert.id
        title = alert.header
        coordinate = alert.coordinate
        severity = alert.severity
        reportedAt = alert.reportedAt
        self.weight = weight
    }

    /// A route passing closer than this counts as passing the danger.
    var radius: CLLocationDistance {
        switch severity {
        case .low: return 60
        case .medium: return 100
        case .high: return 150
        }
    }

    /// Extra walking time the planner accepts to avoid this danger. Newer and more severe dangers
    /// are worth a longer detour; dangers older than 24 hours are not avoided at all.
    func penalty(now: Date = .now) -> TimeInterval {
        let base: TimeInterval
        switch severity {
        case .low: base = 5 * 60
        case .medium: base = 10 * 60
        case .high: base = 20 * 60
        }
        let hours = now.timeIntervalSince(reportedAt) / 3600
        let recency: Double
        switch hours {
        case ..<4: recency = 1
        case ..<12: recency = 0.6
        case ..<24: recency = 0.3
        default: recency = 0
        }
        return base * recency * weight
    }
}

/// A walking route, scored by its travel time plus a penalty for each danger it passes.
struct SafeRoute: Identifiable {
    let id = UUID()
    let polyline: MKPolyline
    let travelTime: TimeInterval
    let distance: CLLocationDistance
    let dangersPassed: [RouteDanger]
    /// Turn-by-turn walking instructions from Apple Maps
    var steps: [WalkingStep] = []

    var penalty: TimeInterval {
        dangersPassed.reduce(0) { $0 + $1.penalty() }
    }

    /// Lower is better: the fastest route wins unless it passes dangers worth detouring around.
    var score: TimeInterval {
        travelTime + penalty
    }
}

/// One turn-by-turn walking instruction.
struct WalkingStep: Identifiable {
    let id: Int
    let instruction: String
    let distance: CLLocationDistance
}

/// How the user wants to travel along the safe route.
enum RouteMode: String, CaseIterable, Identifiable {
    case walk
    case transit

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .walk: return "Walk"
        case .transit: return "Public transport"
        }
    }

    var systemImage: String {
        switch self {
        case .walk: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }
}

/// A public transport trip with the dangers along it: on the walking parts, and at the stops where
/// the user gets on, off or changes. Riding through a station doesn't count.
struct ScoredTransitTrip: Identifiable {
    let trip: TransitTrip
    let dangersPassed: [RouteDanger]

    var id: String { trip.id }

    var penalty: TimeInterval {
        dangersPassed.reduce(0) { $0 + $1.penalty() }
    }

    /// Lower is better: the earliest arrival wins unless dangers on the way are worth avoiding
    func score(now: Date = .now) -> TimeInterval {
        (trip.arrival ?? .distantFuture).timeIntervalSince(now) + penalty
    }
}

/// Something that changed on the active route since it was planned, shown as a banner and notification.
struct RouteUpdate: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    /// True when the new danger made the planner pick a different way
    let isRerouted: Bool
}

/// The recommended route to a destination, with the fastest route for comparison.
struct SafeRoutePlan {
    let destinationName: String
    let destination: CLLocationCoordinate2D
    let recommended: SafeRoute
    let fastest: SafeRoute
    /// Every other route considered, drawn faintly on the map.
    let alternatives: [SafeRoute]
    /// Public transport options, best (earliest arrival + danger penalty) first. Empty when none were found.
    var transitTrips: [ScoredTransitTrip] = []

    /// Whether going by public transport gets the user there meaningfully sooner than walking
    var isTransitFaster: Bool {
        guard let best = transitTrips.first else { return false }
        return best.score() + 3 * 60 < recommended.score
    }

    /// How much longer the recommended route is than the fastest one.
    var extraTime: TimeInterval {
        max(0, recommended.travelTime - fastest.travelTime)
    }

    /// Dangers on the fastest route that the recommended route avoids.
    var avoidedDangers: [RouteDanger] {
        let passed = Set(recommended.dangersPassed.map(\.id))
        return fastest.dangersPassed.filter { !passed.contains($0.id) }
    }
}
