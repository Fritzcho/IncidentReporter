import Foundation
import CoreLocation
import MapKit

/// Finds nearby SL stops, searches SL's full stop register and fetches live departures
/// from SL's open Transport API (https://transport.integration.sl.se, no API key required).
actor SLTransitService {
    static let shared = SLTransitService()

    private let baseURL = URL(string: "https://transport.integration.sl.se/v1")!
    private let session: URLSession
    private var cachedSites: [SLSite]?

    /// Only stops within this distance are considered "nearby".
    private let searchRadius: CLLocationDistance = 3000
    /// Upper bound on how many candidate stops are queried before giving up.
    private let maxCandidates = 64
    private let batchSize = 8
    /// Look 20 hours ahead so a closed station can still report when it reopens.
    private let forecastMinutes = 1200

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/Stockholm")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        // Departures are live data; never answer from a local cache
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    // MARK: - Public API

    /// Returns the nearest stop for each of `TransitMode.nearbyModes` (subway, commuter train, bus).
    /// When one stop is nearest for several modes, it is returned once with all of them.
    func nearestStops(to location: CLLocation) async throws -> [TransitStop] {
        let sites = try await loadSites()
        let candidates = sites
            .map { ($0, location.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon))) }
            .filter { $0.1 <= searchRadius }
            .sorted { $0.1 < $1.1 }
            .prefix(maxCandidates)
            .map(\.0)

        var nearest: [TransitMode: (site: SLSite, departures: [TransitDeparture])] = [:]

        // Query candidates nearest-first in small concurrent batches until every mode is found.
        for batchStart in stride(from: 0, to: candidates.count, by: batchSize) {
            let batch = Array(candidates[batchStart..<min(batchStart + batchSize, candidates.count)])
            let results = await fetchDepartures(for: batch)

            for site in batch {
                guard let departures = results[site.id] else { continue }
                for mode in TransitMode.nearbyModes where nearest[mode] == nil {
                    if departures.contains(where: { $0.mode == mode }) {
                        nearest[mode] = (site, departures)
                    }
                }
            }
            if nearest.count == TransitMode.nearbyModes.count { break }
        }

        var stops: [TransitStop] = []
        for mode in TransitMode.nearbyModes {
            guard let match = nearest[mode] else { continue }
            let modes = TransitMode.nearbyModes.filter { nearest[$0]?.site.id == match.site.id }
            guard !stops.contains(where: { $0.id == match.site.id }) else { continue }
            stops.append(makeStop(site: match.site, modes: modes, departures: match.departures))
        }
        return stops
    }

    /// Searches all SL stops by name (case- and diacritic-insensitive, so "sodra" finds "Stockholms södra").
    /// Name-prefix matches come first, then nearest. With an empty query, returns the stops closest to `location`.
    func searchStops(matching query: String, near location: CLLocation?, limit: Int = 50) async throws -> [TransitStopSummary] {
        let sites = try await loadSites()
        let needle = Self.normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))

        func distance(_ site: SLSite) -> CLLocationDistance {
            location?.distance(from: CLLocation(latitude: site.lat, longitude: site.lon)) ?? 0
        }

        let ranked: [SLSite]
        if needle.isEmpty {
            guard location != nil else { return [] }
            ranked = sites.sorted { distance($0) < distance($1) }
        } else {
            ranked = sites
                .compactMap { site -> (site: SLSite, isPrefix: Bool)? in
                    let name = Self.normalized(site.name)
                    guard name.contains(needle) else { return nil }
                    // "sodra" should rank "Stockholms södra" with "Södra station", not after it
                    let words = name.split(whereSeparator: { " /-(".contains($0) })
                    return (site, name.hasPrefix(needle) || words.contains { $0.hasPrefix(needle) })
                }
                .sorted { lhs, rhs in
                    if lhs.isPrefix != rhs.isPrefix { return lhs.isPrefix }
                    return distance(lhs.site) < distance(rhs.site)
                }
                .map(\.site)
        }
        return ranked.prefix(limit).map(\.summary)
    }

    /// SL stops inside a map region, nearest the region's centre first (used to draw stop markers when zoomed in).
    func stops(in region: MKCoordinateRegion, limit: Int = 150) async throws -> [TransitStopSummary] {
        let sites = try await loadSites()
        let center = region.center
        let latRange = (center.latitude - region.span.latitudeDelta / 2)...(center.latitude + region.span.latitudeDelta / 2)
        let lonRange = (center.longitude - region.span.longitudeDelta / 2)...(center.longitude + region.span.longitudeDelta / 2)
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return sites
            .filter { latRange.contains($0.lat) && lonRange.contains($0.lon) }
            .sorted {
                centerLocation.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon))
                    < centerLocation.distance(from: CLLocation(latitude: $1.lat, longitude: $1.lon))
            }
            .prefix(limit)
            .map(\.summary)
    }

    /// The SL stop closest to `coordinate`, if one is within `maxDistance` (used for taps on the map's transit icons).
    func nearestStop(to coordinate: CLLocationCoordinate2D, within maxDistance: CLLocationDistance = 300) async throws -> TransitStopSummary? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let sites = try await loadSites()
        guard let closest = sites.min(by: {
            target.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lon))
                < target.distance(from: CLLocation(latitude: $1.lat, longitude: $1.lon))
        }) else { return nil }
        let distance = target.distance(from: CLLocation(latitude: closest.lat, longitude: closest.lon))
        return distance <= maxDistance ? closest.summary : nil
    }

    /// Loads live departures for any stop, showing every mode that currently departs from it.
    func stop(for summary: TransitStopSummary) async throws -> TransitStop {
        let departures = try await departures(siteID: summary.id)
        let modes = TransitMode.allCases.filter { mode in departures.contains { $0.mode == mode } }
        return TransitStop(
            id: summary.id,
            name: summary.name,
            coordinate: summary.coordinate,
            modes: modes,
            departures: departures,
            fetchedAt: .now
        )
    }

    /// Re-fetches departures for a stop that is already shown.
    func refresh(_ stop: TransitStop) async throws -> TransitStop {
        let departures = try await departures(siteID: stop.id)
        // A looked-up stop with nothing departing earlier picks up whatever modes appear now
        let modes = stop.modes.isEmpty
            ? TransitMode.allCases.filter { mode in departures.contains { $0.mode == mode } }
            : stop.modes
        return TransitStop(
            id: stop.id,
            name: stop.name,
            coordinate: stop.coordinate,
            modes: modes,
            departures: departures.filter { modes.contains($0.mode) },
            fetchedAt: .now
        )
    }

    // MARK: - Networking

    private func loadSites() async throws -> [SLSite] {
        if let cachedSites { return cachedSites }
        let (data, _) = try await session.data(from: baseURL.appending(path: "sites"))
        let sites = try JSONDecoder().decode([SLSitePayload].self, from: data).compactMap(\.site)
        cachedSites = sites
        return sites
    }

    private func fetchDepartures(for sites: [SLSite]) async -> [Int: [TransitDeparture]] {
        await withTaskGroup(of: (Int, [TransitDeparture]?).self) { group in
            for site in sites {
                group.addTask {
                    (site.id, try? await self.departures(siteID: site.id))
                }
            }
            var results: [Int: [TransitDeparture]] = [:]
            for await (id, departures) in group {
                results[id] = departures
            }
            return results
        }
    }

    private func departures(siteID: Int) async throws -> [TransitDeparture] {
        var components = URLComponents(
            url: baseURL.appending(path: "sites/\(siteID)/departures"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "forecast", value: String(forecastMinutes))]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(SLDeparturesResponse.self, from: data)

        return response.departures.compactMap { departure in
            guard departure.state != "CANCELLED",
                  let mode = TransitMode(rawValue: departure.line.transportMode),
                  let scheduled = dateFormatter.date(from: departure.scheduled) else {
                return nil
            }
            let expected = departure.expected.flatMap { dateFormatter.date(from: $0) } ?? scheduled
            return TransitDeparture(
                id: "\(departure.journey.id)-\(departure.stopPoint?.id ?? 0)",
                mode: mode,
                line: departure.line.designation,
                destination: departure.destination,
                scheduled: scheduled,
                expected: expected,
                platform: departure.stopPoint?.designation
            )
        }
        .sorted { $0.expected < $1.expected }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "sv_SE"))
    }

    private func makeStop(site: SLSite, modes: [TransitMode], departures: [TransitDeparture]) -> TransitStop {
        TransitStop(
            id: site.id,
            name: site.name,
            coordinate: CLLocationCoordinate2D(latitude: site.lat, longitude: site.lon),
            modes: modes,
            departures: departures.filter { modes.contains($0.mode) },
            fetchedAt: .now
        )
    }
}

// MARK: - SL Transport API payloads

private nonisolated struct SLSite: Sendable {
    let id: Int
    let name: String
    let note: String?
    let lat: Double
    let lon: Double

    var summary: TransitStopSummary {
        TransitStopSummary(id: id, name: name, note: note, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }
}

/// Raw site entry; a few SL sites have no coordinates and are dropped.
private nonisolated struct SLSitePayload: Decodable, Sendable {
    let id: Int
    let name: String
    let note: String?
    let lat: Double?
    let lon: Double?

    var site: SLSite? {
        guard let lat, let lon else { return nil }
        return SLSite(id: id, name: name, note: note, lat: lat, lon: lon)
    }
}

private nonisolated struct SLDeparturesResponse: Decodable, Sendable {
    let departures: [SLDeparture]
}

private nonisolated struct SLDeparture: Decodable, Sendable {
    struct Journey: Decodable, Sendable {
        let id: Int
    }

    struct StopPoint: Decodable, Sendable {
        let id: Int
        let designation: String?
    }

    struct Line: Decodable, Sendable {
        let designation: String
        let transportMode: String

        enum CodingKeys: String, CodingKey {
            case designation
            case transportMode = "transport_mode"
        }
    }

    let destination: String
    let state: String?
    let scheduled: String
    let expected: String?
    let journey: Journey
    let stopPoint: StopPoint?
    let line: Line

    enum CodingKeys: String, CodingKey {
        case destination, state, scheduled, expected, journey, line
        case stopPoint = "stop_point"
    }
}
