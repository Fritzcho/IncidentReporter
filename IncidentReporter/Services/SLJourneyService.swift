import Foundation
import CoreLocation

/// Door-to-door public transport trips from SL's open journey planner
/// (https://journeyplanner.integration.sl.se/v2, no API key required), with real-time times.
actor SLJourneyService {
    static let shared = SLJourneyService()

    private let baseURL = URL(string: "https://journeyplanner.integration.sl.se/v2/trips")!
    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    /// Upcoming trips leaving now, soonest arrival first. SL allows at most 3 per request.
    func trips(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, count: Int = 3) async throws -> [TransitTrip] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "type_origin", value: "coord"),
            URLQueryItem(name: "name_origin", value: Self.coordinateParameter(origin)),
            URLQueryItem(name: "type_destination", value: "coord"),
            URLQueryItem(name: "name_destination", value: Self.coordinateParameter(destination)),
            URLQueryItem(name: "calc_number_of_trips", value: String(count))
        ]
        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(SLTripsResponse.self, from: data)

        let trips = response.journeys.compactMap { journey -> TransitTrip? in
            let legs = Self.mergedWalks(journey.legs.enumerated().compactMap { Self.leg(from: $1, index: $0) })
            // Walking-only answers are covered by the walking route
            guard legs.contains(where: { !$0.isWalk }) else { return nil }
            return TransitTrip(legs: legs)
        }
        // SL sometimes returns the same trip twice
        var seen = Set<String>()
        return trips
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.arrival ?? .distantFuture) < ($1.arrival ?? .distantFuture) }
    }

    // MARK: - Parsing

    private static func coordinateParameter(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f:%.6f:WGS84[dd.ddddd]", coordinate.longitude, coordinate.latitude)
    }

    private static func leg(from payload: SLTripsResponse.Leg, index: Int) -> TripLeg? {
        guard let from = stop(from: payload.origin, departure: true),
              let to = stop(from: payload.destination, departure: false) else {
            return nil
        }
        let productClass = payload.transportation?.product?.productClass ?? 100
        let isWalk = productClass == 99 || productClass == 100
        let intermediate = (payload.stopSequence ?? []).dropFirst().dropLast().compactMap { stop(from: $0, departure: true) }
        return TripLeg(
            id: index,
            mode: isWalk ? nil : mode(productClass: productClass, name: payload.transportation?.product?.name),
            line: isWalk ? nil : (payload.transportation?.disassembledName ?? payload.transportation?.number),
            direction: payload.transportation?.destination?.name,
            from: from,
            to: to,
            intermediateStops: intermediate,
            coordinates: (payload.coords ?? []).compactMap { pair in
                pair.count >= 2 ? CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1]) : nil
            },
            // Class 99 is SL's walk between platforms when changing
            isTransfer: productClass == 99
        )
    }

    private static func stop(from payload: SLTripsResponse.Location, departure: Bool) -> TripStop? {
        guard let coord = payload.coord, coord.count >= 2 else { return nil }
        let planned = departure ? payload.departureTimePlanned : payload.arrivalTimePlanned
        let estimated = departure ? payload.departureTimeEstimated : payload.arrivalTimeEstimated
        return TripStop(
            name: payload.parent?.disassembledName ?? payload.disassembledName ?? payload.name,
            coordinate: CLLocationCoordinate2D(latitude: coord[0], longitude: coord[1]),
            platform: payload.properties?.platform,
            plannedTime: planned.flatMap(date(from:)) ?? (departure ? payload.arrivalTimePlanned : payload.departureTimePlanned).flatMap(date(from:)),
            estimatedTime: estimated.flatMap(date(from:))
        )
    }

    /// SL splits a walk into a street part and an in-station part; show them as one step
    private static func mergedWalks(_ legs: [TripLeg]) -> [TripLeg] {
        var result: [TripLeg] = []
        for leg in legs {
            if leg.isWalk, let previous = result.last, previous.isWalk {
                result[result.count - 1] = TripLeg(
                    id: previous.id,
                    mode: nil,
                    line: nil,
                    direction: nil,
                    from: previous.from,
                    to: leg.to,
                    intermediateStops: [],
                    coordinates: previous.coordinates + leg.coordinates,
                    isTransfer: previous.isTransfer && leg.isTransfer
                )
            } else {
                result.append(leg)
            }
        }
        return result
    }

    /// SL product classes: 0 train, 2 metro, 4 tram/light rail, 5 bus, 9 boat (with name as fallback)
    private static func mode(productClass: Int, name: String?) -> TransitMode {
        switch productClass {
        case 0, 1: return .train
        case 2: return .metro
        case 4: return .tram
        case 5, 6, 7: return .bus
        case 9, 10: return .ship
        default:
            let lowered = name?.lowercased() ?? ""
            if lowered.contains("tunnelbana") { return .metro }
            if lowered.contains("tåg") { return .train }
            if lowered.contains("spår") || lowered.contains("lokalbana") { return .tram }
            if lowered.contains("båt") || lowered.contains("färja") { return .ship }
            return .bus
        }
    }

    private static func date(from text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }
}

// MARK: - SL Journey Planner payloads

private nonisolated struct SLTripsResponse: Decodable, Sendable {
    struct Location: Decodable, Sendable {
        struct Parent: Decodable, Sendable {
            let disassembledName: String?
        }

        struct Properties: Decodable, Sendable {
            let platform: String?
        }

        let name: String
        let disassembledName: String?
        let coord: [Double]?
        let parent: Parent?
        let properties: Properties?
        let departureTimePlanned: String?
        let departureTimeEstimated: String?
        let arrivalTimePlanned: String?
        let arrivalTimeEstimated: String?
    }

    struct Transportation: Decodable, Sendable {
        struct Product: Decodable, Sendable {
            let productClass: Int?
            let name: String?

            enum CodingKeys: String, CodingKey {
                case productClass = "class"
                case name
            }
        }

        struct Destination: Decodable, Sendable {
            let name: String?
        }

        let product: Product?
        let disassembledName: String?
        let number: String?
        let destination: Destination?
    }

    struct Leg: Decodable, Sendable {
        let origin: Location
        let destination: Location
        let transportation: Transportation?
        let stopSequence: [Location]?
        let coords: [[Double]]?
    }

    struct Journey: Decodable, Sendable {
        let legs: [Leg]
    }

    let journeys: [Journey]
}
