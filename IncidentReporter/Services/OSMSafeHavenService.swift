import Foundation
import CoreLocation

/// Staffed or always-open places from OpenStreetMap (police, pharmacies, emergency departments,
/// convenience stores, hotel receptions), with their opening hours where mappers have added them.
/// The public Overpass API is slow (often 30 s+) and rate-limited, so each ~2 km area is fetched once
/// and cached on disk for a day.
actor OSMSafeHavenService {
    static let shared = OSMSafeHavenService()

    private let endpoint = URL(string: "https://overpass-api.de/api/interpreter")!
    /// The public server often answers 502/504 when busy; a retry a few seconds later usually works
    private let retryDelays: [Duration] = [.zero, .seconds(3), .seconds(8)]
    private let session: URLSession
    private let cacheLifetime: TimeInterval = 24 * 60 * 60
    private let searchRadius: CLLocationDistance = 2000
    /// Areas loaded this session, so panning back doesn't refetch
    private var loadedAreas: [String: [SafeHaven]] = [:]
    private var inFlight: [String: Task<[SafeHaven], Never>] = [:]

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 50
        configuration.httpAdditionalHeaders = ["User-Agent": "IncidentTracker/1.0 (iOS personal safety app)"]
        session = URLSession(configuration: configuration)
    }

    /// Safe havens in the ~2 km area around `coordinate`. Never throws: returns [] when OpenStreetMap is unreachable.
    func havens(around coordinate: CLLocationCoordinate2D) async -> [SafeHaven] {
        // Snap to a grid so nearby requests share one query and cache entry
        let latitude = (coordinate.latitude * 50).rounded() / 50
        let longitude = (coordinate.longitude * 25).rounded() / 25
        let key = String(format: "%.2f_%.2f", latitude, longitude)

        if let cached = loadedAreas[key] { return cached }
        if let running = inFlight[key] { return await running.value }

        let task = Task { await self.load(key: key, center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)) }
        inFlight[key] = task
        let havens = await task.value
        inFlight[key] = nil
        if !havens.isEmpty {
            loadedAreas[key] = havens
        }
        return havens
    }

    private func load(key: String, center: CLLocationCoordinate2D) async -> [SafeHaven] {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("osm-havens-\(key).json")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
           let modified = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) < cacheLifetime,
           let data = try? Data(contentsOf: cacheURL),
           let havens = try? Self.havens(from: data) {
            return havens
        }

        let around = String(format: "around:%.0f,%.5f,%.5f", searchRadius, center.latitude, center.longitude)
        let query = """
        [out:json][timeout:45];
        (
          nwr["amenity"~"^(police|pharmacy)$"](\(around));
          nwr["amenity"="hospital"]["emergency"="yes"](\(around));
          nwr["healthcare"="hospital"]["emergency"="yes"](\(around));
          nwr["shop"="convenience"](\(around));
          nwr["amenity"="fuel"]["opening_hours"](\(around));
          nwr["tourism"="hotel"](\(around));
        );
        out center tags;
        """
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")".data(using: .utf8)
        for delay in retryDelays {
            try? await Task.sleep(for: delay)
            guard let (data, response) = try? await session.data(for: request),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let havens = try? Self.havens(from: data) else {
                continue
            }
            try? data.write(to: cacheURL)
            return havens
        }
        return []
    }

    // MARK: - Parsing

    private static func havens(from data: Data) throws -> [SafeHaven] {
        try JSONDecoder().decode(OverpassResponse.self, from: data).elements.compactMap(haven(from:))
    }

    private static func haven(from element: OverpassResponse.Element) -> SafeHaven? {
        let tags = element.tags ?? [:]
        guard let name = tags["name"], !name.isEmpty,
              let lat = element.lat ?? element.center?.lat,
              let lon = element.lon ?? element.center?.lon,
              let category = category(for: tags) else {
            return nil
        }
        let hours = tags["opening_hours"]
        let street = [tags["addr:street"], tags["addr:housenumber"]].compactMap { $0 }.joined(separator: " ")
        return SafeHaven(
            name: name,
            category: category,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            address: street.isEmpty ? (tags["addr:city"] ?? String(localized: "Address not listed")) : street,
            isOpen24Hours: hours?.trimmingCharacters(in: .whitespaces) == "24/7",
            note: note(for: category),
            openingHoursText: hours,
            source: .openStreetMap
        )
    }

    private static func category(for tags: [String: String]) -> SafeHavenCategory? {
        switch tags["amenity"] {
        case "police": return .policeStation
        case "pharmacy": return .pharmacy
        case "hospital": return .hospital
        case "fuel": return .convenienceStore
        default: break
        }
        if tags["healthcare"] == "hospital" { return .hospital }
        if tags["shop"] == "convenience" { return .convenienceStore }
        if tags["tourism"] == "hotel" { return .hotel }
        return nil
    }

    private static func note(for category: SafeHavenCategory) -> String {
        switch category {
        case .policeStation: return String(localized: "Police station. In an emergency, call 112.")
        case .pharmacy: return String(localized: "Staffed pharmacy during opening hours.")
        case .hospital: return String(localized: "Emergency department with staffed reception.")
        case .convenienceStore: return String(localized: "Staffed shop: step inside and ask staff for help.")
        case .hotel: return String(localized: "Hotel reception, often staffed through the night. Ask at the desk for help.")
        case .transitHub: return String(localized: "Staffed transit point.")
        }
    }
}

private nonisolated struct OverpassResponse: Decodable, Sendable {
    struct Element: Decodable, Sendable {
        struct Center: Decodable, Sendable {
            let lat: Double
            let lon: Double
        }

        let lat: Double?
        let lon: Double?
        let center: Center?
        let tags: [String: String]?
    }

    let elements: [Element]
}
