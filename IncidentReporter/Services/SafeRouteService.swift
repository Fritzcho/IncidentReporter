import Foundation
import MapKit

/// Plans walking routes that are as fast as possible while steering around recent dangers.
enum SafeRouteService {
    enum PlanningError: Error {
        case noRoute
    }

    /// How far beyond a danger's radius a detour is aimed.
    private static let detourClearance: CLLocationDistance = 150

    /// Asks Apple Maps for walking routes (plus detours around the worst danger on the fastest one)
    /// and picks the route with the lowest travel time + danger penalty.
    static func plan(
        from origin: CLLocationCoordinate2D,
        to destination: MKMapItem,
        avoiding dangers: [RouteDanger]
    ) async throws -> SafeRoutePlan {
        let originItem = MKMapItem(location: CLLocation(latitude: origin.latitude, longitude: origin.longitude), address: nil)

        var routes = try await walkingRoutes(from: originItem, to: destination, alternatives: true)
            .map { route in
                var scoredRoute = scored(polyline: route.polyline, travelTime: route.expectedTravelTime, distance: route.distance, dangers: dangers)
                scoredRoute.steps = walkingSteps(route.steps)
                return scoredRoute
            }
        guard let fastest = routes.min(by: { $0.travelTime < $1.travelTime }) else {
            throw PlanningError.noRoute
        }

        // Apple's alternatives don't know about dangers, so also try going round the worst one on either side
        if let worst = fastest.dangersPassed.max(by: { $0.penalty() < $1.penalty() }) {
            for waypoint in detourWaypoints(around: worst, on: fastest.polyline) {
                if let detour = try? await route(from: originItem, via: waypoint, to: destination, dangers: dangers) {
                    routes.append(detour)
                }
            }
        }

        guard let recommended = routes.min(by: { $0.score < $1.score }) else {
            throw PlanningError.noRoute
        }
        // Public transport is a bonus: if SL can't be reached the walking route still works
        let trips = (try? await SLJourneyService.shared.trips(from: origin, to: destination.location.coordinate)) ?? []
        return SafeRoutePlan(
            destinationName: destination.name ?? String(localized: "Destination"),
            destination: destination.location.coordinate,
            recommended: recommended,
            fastest: fastest,
            alternatives: routes.filter { $0.id != recommended.id },
            transitTrips: trips
                .map { scored(trip: $0, dangers: dangers) }
                .sorted { $0.score() < $1.score() }
        )
    }

    /// Dangers along a trip: near its walking parts, and at the stops where the user gets on, off or changes.
    private static func scored(trip: TransitTrip, dangers: [RouteDanger]) -> ScoredTransitTrip {
        let walks = trip.legs.filter(\.isWalk).map(\.polyline)
        let stops = trip.rides.flatMap { [$0.from.coordinate, $0.to.coordinate] }
        let passed = dangers.filter { danger in
            let target = CLLocation(latitude: danger.coordinate.latitude, longitude: danger.coordinate.longitude)
            return walks.contains { distance(from: danger.coordinate, to: $0) <= danger.radius }
                || stops.contains { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: target) <= danger.radius + 50 }
        }
        return ScoredTransitTrip(trip: trip, dangersPassed: passed)
    }

    /// Dangers that weren't known at the last plan and lie on (or close to) any of `routes`:
    /// the way the user was following and the new one.
    static func newDangers(
        in dangers: [RouteDanger],
        knownIDs: Set<String>,
        near routes: [MKPolyline],
        buffer: CLLocationDistance = 100
    ) -> [RouteDanger] {
        dangers.filter { danger in
            !knownIDs.contains(danger.id) && routes.contains { route in
                distance(from: danger.coordinate, to: route) <= danger.radius + buffer
            }
        }
    }

    // MARK: - Routing

    private static func walkingRoutes(from source: MKMapItem, to destination: MKMapItem, alternatives: Bool) async throws -> [MKRoute] {
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .walking
        request.requestsAlternateRoutes = alternatives
        return try await MKDirections(request: request).calculate().routes
    }

    /// A route forced through `waypoint`, built from two walking legs.
    private static func route(
        from source: MKMapItem,
        via waypoint: CLLocationCoordinate2D,
        to destination: MKMapItem,
        dangers: [RouteDanger]
    ) async throws -> SafeRoute {
        let waypointItem = MKMapItem(location: CLLocation(latitude: waypoint.latitude, longitude: waypoint.longitude), address: nil)
        async let firstLeg = walkingRoutes(from: source, to: waypointItem, alternatives: false)
        async let secondLeg = walkingRoutes(from: waypointItem, to: destination, alternatives: false)
        guard let first = try await firstLeg.first, let second = try await secondLeg.first else {
            throw PlanningError.noRoute
        }
        let points = mapPoints(of: first.polyline) + mapPoints(of: second.polyline)
        var detour = scored(
            polyline: MKPolyline(points: points, count: points.count),
            travelTime: first.expectedTravelTime + second.expectedTravelTime,
            distance: first.distance + second.distance,
            dangers: dangers
        )
        detour.steps = walkingSteps(first.steps + second.steps)
        return detour
    }

    /// Apple's steps without the empty "start" step and the leg-joining "arrive at waypoint" step
    private static func walkingSteps(_ steps: [MKRoute.Step]) -> [WalkingStep] {
        steps
            .filter { !$0.instructions.isEmpty && $0.distance > 0 }
            .enumerated()
            .map { WalkingStep(id: $0, instruction: $1.instructions, distance: $1.distance) }
    }

    private static func scored(polyline: MKPolyline, travelTime: TimeInterval, distance: CLLocationDistance, dangers: [RouteDanger]) -> SafeRoute {
        SafeRoute(
            polyline: polyline,
            travelTime: travelTime,
            distance: distance,
            dangersPassed: dangers.filter { self.distance(from: $0.coordinate, to: polyline) <= $0.radius }
        )
    }

    // MARK: - Geometry

    private static func mapPoints(of polyline: MKPolyline) -> [MKMapPoint] {
        Array(UnsafeBufferPointer(start: polyline.points(), count: polyline.pointCount))
    }

    /// Shortest distance in metres from a coordinate to any segment of the polyline.
    static func distance(from coordinate: CLLocationCoordinate2D, to polyline: MKPolyline) -> CLLocationDistance {
        let point = MKMapPoint(coordinate)
        let points = mapPoints(of: polyline)
        guard let first = points.first else { return .infinity }
        guard points.count > 1 else { return point.distance(to: first) }
        var best = CLLocationDistance.infinity
        for (a, b) in zip(points, points.dropFirst()) {
            best = min(best, point.distance(to: closestPoint(to: point, onSegmentFrom: a, to: b)))
        }
        return best
    }

    private static func closestPoint(to p: MKMapPoint, onSegmentFrom a: MKMapPoint, to b: MKMapPoint) -> MKMapPoint {
        let dx = b.x - a.x, dy = b.y - a.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else { return a }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSquared))
        return MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
    }

    /// Two points beside the danger, one on each side of the route, far enough out to clear it.
    private static func detourWaypoints(around danger: RouteDanger, on polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        let center = MKMapPoint(danger.coordinate)
        let points = mapPoints(of: polyline)
        guard points.count > 1 else { return [] }

        // Direction of the route where it passes closest to the danger
        let segment = zip(points, points.dropFirst()).min { lhs, rhs in
            center.distance(to: closestPoint(to: center, onSegmentFrom: lhs.0, to: lhs.1))
                < center.distance(to: closestPoint(to: center, onSegmentFrom: rhs.0, to: rhs.1))
        }
        guard let (a, b) = segment else { return [] }
        let dx = b.x - a.x, dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return [] }

        let offset = (danger.radius + detourClearance) / MKMetersPerMapPointAtLatitude(danger.coordinate.latitude)
        let normal = (x: -dy / length, y: dx / length)
        return [1.0, -1.0].map { side in
            MKMapPoint(x: center.x + normal.x * offset * side, y: center.y + normal.y * offset * side).coordinate
        }
    }
}
