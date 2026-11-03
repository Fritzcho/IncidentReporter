import Foundation
import CoreLocation
import MapKit

/// A stop (or address) a trip leg starts or ends at, or passes.
nonisolated struct TripStop: Hashable, Sendable {
    let name: String
    let coordinate: CLLocationCoordinate2D
    let platform: String?
    let plannedTime: Date?
    /// Real-time estimate from SL, when there is one
    let estimatedTime: Date?

    var time: Date? { estimatedTime ?? plannedTime }

    var delayMinutes: Int {
        guard let plannedTime, let estimatedTime else { return 0 }
        return Int((estimatedTime.timeIntervalSince(plannedTime) / 60).rounded())
    }

    static func == (lhs: TripStop, rhs: TripStop) -> Bool {
        lhs.name == rhs.name && lhs.plannedTime == rhs.plannedTime
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(plannedTime)
    }
}

/// One part of a trip: a walk, or a ride on one line.
nonisolated struct TripLeg: Identifiable, Hashable, Sendable {
    let id: Int
    /// nil for walking
    let mode: TransitMode?
    /// Line number, e.g. "10" or "43X"
    let line: String?
    /// Final stop of the vehicle, e.g. "Hjulsta"
    let direction: String?
    let from: TripStop
    let to: TripStop
    /// Stops passed on the way (not including `from` and `to`)
    let intermediateStops: [TripStop]
    let coordinates: [CLLocationCoordinate2D]
    /// A short walk between platforms inside a station
    let isTransfer: Bool

    var isWalk: Bool { mode == nil }

    var duration: TimeInterval {
        guard let start = from.time, let end = to.time else { return 0 }
        return max(0, end.timeIntervalSince(start))
    }

    var polyline: MKPolyline {
        MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    static func == (lhs: TripLeg, rhs: TripLeg) -> Bool {
        lhs.id == rhs.id && lhs.from == rhs.from && lhs.to == rhs.to
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(from)
    }
}

/// A door-to-door public transport trip from SL's journey planner.
nonisolated struct TransitTrip: Identifiable, Hashable, Sendable {
    let legs: [TripLeg]

    /// Same line, same departure: stays stable when the trip is re-planned with fresh real-time data
    var id: String {
        rides.map { "\($0.line ?? "")@\($0.from.plannedTime?.timeIntervalSince1970 ?? 0)" }.joined(separator: "|")
    }

    var rides: [TripLeg] { legs.filter { !$0.isWalk } }

    var departure: Date? { legs.first?.from.time }
    var arrival: Date? { legs.last?.to.time }

    var changes: Int { max(0, rides.count - 1) }

    /// When the first vehicle leaves; the user has to be at the stop by then
    var firstRideDeparture: Date? { rides.first?.from.time }

    var walkingDistanceHint: TimeInterval {
        legs.filter(\.isWalk).reduce(0) { $0 + $1.duration }
    }

    var polyline: MKPolyline {
        let coordinates = legs.flatMap(\.coordinates)
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    static func == (lhs: TransitTrip, rhs: TransitTrip) -> Bool {
        lhs.id == rhs.id && lhs.arrival == rhs.arrival
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
