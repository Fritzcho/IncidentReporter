import Foundation
import CoreLocation

/// Reads SL's open disruption feed (https://deviations.integration.sl.se, no API key) and keeps only
/// safety-related messages, such as police operations or people on the tracks, placed at the stops they affect.
actor SLDeviationService {
    static let shared = SLDeviationService()

    private let feedURL = URL(string: "https://deviations.integration.sl.se/v1/messages?future=false")!
    private let session: URLSession
    private var cache: (alerts: [TransitSafetyAlert], fetchedAt: Date)?
    /// Disruptions change quickly but the feed is large; don't refetch more often than this
    private let cacheLifetime: TimeInterval = 60

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    /// Safety-related disruptions active right now, one per affected stop.
    func safetyAlerts() async throws -> [TransitSafetyAlert] {
        if let cache, Date().timeIntervalSince(cache.fetchedAt) < cacheLifetime {
            return cache.alerts
        }
        let (data, _) = try await session.data(from: feedURL)
        let messages = try JSONDecoder().decode([SLDeviationMessage].self, from: data)

        let relevant = messages.compactMap { message -> (SLDeviationMessage, SLDeviationMessage.Variant, IncidentSeverity)? in
            guard let variant = message.swedishVariant,
                  let severity = TransitSafetyAlert.severity(forMessage: variant.header + " " + variant.details) else {
                return nil
            }
            return (message, variant, severity)
        }
        let areaIDs = Set(relevant.flatMap { $0.0.scope?.stopAreas?.map(\.id) ?? [] })
        let stopsByArea = try await SLTransitService.shared.stops(forStopAreas: areaIDs)

        var alerts: [TransitSafetyAlert] = []
        for (message, variant, severity) in relevant {
            let modes = Set((message.scope?.lines ?? []).compactMap { TransitMode(rawValue: $0.transportMode) })
            var seenStops = Set<Int>()
            for area in message.scope?.stopAreas ?? [] {
                // Several stop areas (platforms, entrances) can belong to the same stop
                guard let stop = stopsByArea[area.id], seenStops.insert(stop.id).inserted else { continue }
                alerts.append(TransitSafetyAlert(
                    id: "\(message.caseID)-\(stop.id)",
                    caseID: message.caseID,
                    stopName: stop.name,
                    coordinate: stop.coordinate,
                    header: variant.header,
                    details: variant.details,
                    affectedLines: variant.scopeAlias,
                    modes: TransitMode.allCases.filter { modes.contains($0) || (modes.isEmpty && stop.modes.contains($0)) },
                    severity: severity,
                    reportedAt: message.createdDate ?? .now
                ))
            }
        }
        cache = (alerts, .now)
        return alerts
    }
}

// MARK: - SL Deviations API payloads

private nonisolated struct SLDeviationMessage: Decodable, Sendable {
    struct Variant: Decodable, Sendable {
        let header: String
        let details: String
        let scopeAlias: String?
        let language: String

        enum CodingKeys: String, CodingKey {
            case header, details, language
            case scopeAlias = "scope_alias"
        }
    }

    struct Scope: Decodable, Sendable {
        struct StopArea: Decodable, Sendable {
            let id: Int
        }

        struct Line: Decodable, Sendable {
            let transportMode: String

            enum CodingKeys: String, CodingKey {
                case transportMode = "transport_mode"
            }
        }

        let stopAreas: [StopArea]?
        let lines: [Line]?

        enum CodingKeys: String, CodingKey {
            case stopAreas = "stop_areas"
            case lines
        }
    }

    let caseID: Int
    let created: String
    let messageVariants: [Variant]
    let scope: Scope?

    enum CodingKeys: String, CodingKey {
        case caseID = "deviation_case_id"
        case created
        case messageVariants = "message_variants"
        case scope
    }

    var swedishVariant: Variant? {
        messageVariants.first { $0.language == "sv" } ?? messageVariants.first
    }

    /// SL sends timestamps both with and without fractional seconds
    var createdDate: Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: created) ?? ISO8601DateFormatter().date(from: created)
    }
}
