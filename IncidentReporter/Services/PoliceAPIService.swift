import Foundation
import CoreLocation
import SwiftData

/// Service to fetch and filter live events from the Swedish Police API (polisen.se).
enum PoliceAPIService {
    private static let apiURL = URL(string: "https://polisen.se/api/events")!

    // MARK: - Sync State Management
    private static var isSyncing = false
    private static var lastSyncDate: Date?

    // MARK: - API Models
    struct PoliceEventDTO: Decodable {
        let id: Int
        let datetime: String
        let name: String
        let summary: String
        let url: String
        let type: String
        let location: PoliceLocationDTO

        struct PoliceLocationDTO: Decodable {
            let name: String
            let gps: String
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let fallbackDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd H:mm:ss ZZZZZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Flexible date parsing supporting both single-digit and two-digit hours from polisen.se
    private static func parseDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.components(separatedBy: " ")
        let normalized: String
        if parts.count == 3 && parts[1].count == 7 { // Single-digit hour format e.g. "8:10:55"
            normalized = "\(parts[0]) 0\(parts[1]) \(parts[2])"
        } else {
            normalized = trimmed
        }
        return dateFormatter.date(from: normalized) ?? fallbackDateFormatter.date(from: trimmed)
    }

    // MARK: - Geographic Lookup Tables
    private static let districtCoordinates: [(keyword: String, coord: CLLocationCoordinate2D, display: String)] = [
        ("södermalm", CLLocationCoordinate2D(latitude: 59.3149, longitude: 18.0716), "Stockholm - Södermalm"),
        ("medborgarplatsen", CLLocationCoordinate2D(latitude: 59.3149, longitude: 18.0716), "Stockholm - Medborgarplatsen"),
        ("folkungagatan", CLLocationCoordinate2D(latitude: 59.3155, longitude: 18.0780), "Stockholm - Södermalm"),
        ("hornstull", CLLocationCoordinate2D(latitude: 59.3158, longitude: 18.0335), "Stockholm - Hornstull"),
        ("slussen", CLLocationCoordinate2D(latitude: 59.3198, longitude: 18.0718), "Stockholm - Slussen"),
        ("drakenbergparken", CLLocationCoordinate2D(latitude: 59.3170, longitude: 18.0400), "Stockholm - Södermalm"),
        ("fiskargatan", CLLocationCoordinate2D(latitude: 59.3185, longitude: 18.0790), "Stockholm - Södermalm"),
        ("norrmalm", CLLocationCoordinate2D(latitude: 59.3360, longitude: 18.0600), "Stockholm - Norrmalm"),
        ("t-centralen", CLLocationCoordinate2D(latitude: 59.3308, longitude: 18.0585), "Stockholm - City"),
        ("centralen", CLLocationCoordinate2D(latitude: 59.3308, longitude: 18.0585), "Stockholm - City"),
        ("sergels torg", CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649), "Stockholm - City"),
        ("hötorget", CLLocationCoordinate2D(latitude: 59.3355, longitude: 18.0625), "Stockholm - City"),
        ("stureplan", CLLocationCoordinate2D(latitude: 59.3364, longitude: 18.0729), "Stockholm - Stureplan"),
        ("östermalm", CLLocationCoordinate2D(latitude: 59.3380, longitude: 18.0850), "Stockholm - Östermalm"),
        ("karlaplan", CLLocationCoordinate2D(latitude: 59.3392, longitude: 18.0905), "Stockholm - Karlaplan"),
        ("kungsholmen", CLLocationCoordinate2D(latitude: 59.3330, longitude: 18.0300), "Stockholm - Kungsholmen"),
        ("fridhemsplan", CLLocationCoordinate2D(latitude: 59.3325, longitude: 18.0305), "Stockholm - Fridhemsplan"),
        ("konradsberg", CLLocationCoordinate2D(latitude: 59.3290, longitude: 18.0160), "Stockholm - Kungsholmen"),
        ("blekholm", CLLocationCoordinate2D(latitude: 59.3320, longitude: 18.0510), "Stockholm - Kungsholmen"),
        ("vasastan", CLLocationCoordinate2D(latitude: 59.3429, longitude: 18.0498), "Stockholm - Vasastan"),
        ("vasastaden", CLLocationCoordinate2D(latitude: 59.3429, longitude: 18.0498), "Stockholm - Vasastan"),
        ("odenplan", CLLocationCoordinate2D(latitude: 59.3429, longitude: 18.0498), "Stockholm - Odenplan"),
        ("gamla stan", CLLocationCoordinate2D(latitude: 59.3248, longitude: 18.0702), "Stockholm - Gamla Stan"),
        ("gärdet", CLLocationCoordinate2D(latitude: 59.3450, longitude: 18.1000), "Stockholm - Gärdet"),
        ("djurgården", CLLocationCoordinate2D(latitude: 59.3280, longitude: 18.1170), "Stockholm - Djurgården"),
        ("liljeholmen", CLLocationCoordinate2D(latitude: 59.3108, longitude: 18.0232), "Stockholm - Liljeholmen"),
        ("hammarby sjöstad", CLLocationCoordinate2D(latitude: 59.3050, longitude: 18.1000), "Stockholm - Hammarby Sjöstad"),
        ("årsta", CLLocationCoordinate2D(latitude: 59.2970, longitude: 18.0500), "Stockholm - Årsta"),
        ("enskede", CLLocationCoordinate2D(latitude: 59.2850, longitude: 18.0800), "Stockholm - Enskede"),
        ("stureby", CLLocationCoordinate2D(latitude: 59.2780, longitude: 18.0750), "Stockholm - Stureby"),
        ("blåsut", CLLocationCoordinate2D(latitude: 59.2920, longitude: 18.0900), "Stockholm - Blåsut"),
        ("solberga", CLLocationCoordinate2D(latitude: 59.2920, longitude: 18.0050), "Stockholm - Solberga"),
        ("bromma", CLLocationCoordinate2D(latitude: 59.3400, longitude: 17.9400), "Stockholm - Bromma"),
        ("ulvsunda", CLLocationCoordinate2D(latitude: 59.3450, longitude: 17.9650), "Stockholm - Ulvsunda"),
        ("hägersten", CLLocationCoordinate2D(latitude: 59.3000, longitude: 18.0000), "Stockholm - Hägersten"),
        ("kista", CLLocationCoordinate2D(latitude: 59.4030, longitude: 17.9440), "Stockholm - Kista"),
        ("skärholmen", CLLocationCoordinate2D(latitude: 59.2750, longitude: 17.9060), "Stockholm - Skärholmen"),
        ("vårby", CLLocationCoordinate2D(latitude: 59.2600, longitude: 17.8800), "Stockholm - Vårby"),
        ("flemingsberg", CLLocationCoordinate2D(latitude: 59.2190, longitude: 17.9400), "Huddinge - Flemingsberg"),
        ("trångsund", CLLocationCoordinate2D(latitude: 59.2300, longitude: 18.1300), "Huddinge - Trångsund"),
        ("segeltorp", CLLocationCoordinate2D(latitude: 59.2750, longitude: 17.9450), "Huddinge - Segeltorp"),
        ("häggvik", CLLocationCoordinate2D(latitude: 59.4440, longitude: 17.9300), "Sollentuna - Häggvik"),
        ("torsvik", CLLocationCoordinate2D(latitude: 59.3658, longitude: 18.1340), "Lidingö - Torsvik")
    ]

    private static let municipalityCoordinates: [String: CLLocationCoordinate2D] = [
        "stockholm": CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649),
        "solna": CLLocationCoordinate2D(latitude: 59.3600, longitude: 18.0000),
        "sundbyberg": CLLocationCoordinate2D(latitude: 59.3614, longitude: 17.9715),
        "danderyd": CLLocationCoordinate2D(latitude: 59.4074, longitude: 18.0441),
        "lidingö": CLLocationCoordinate2D(latitude: 59.3658, longitude: 18.1340),
        "nacka": CLLocationCoordinate2D(latitude: 59.3150, longitude: 18.1630),
        "huddinge": CLLocationCoordinate2D(latitude: 59.2370, longitude: 17.9820),
        "botkyrka": CLLocationCoordinate2D(latitude: 59.2000, longitude: 17.8300),
        "sollentuna": CLLocationCoordinate2D(latitude: 59.4285, longitude: 17.9509),
        "järfälla": CLLocationCoordinate2D(latitude: 59.4230, longitude: 17.8310),
        "täby": CLLocationCoordinate2D(latitude: 59.4439, longitude: 18.0687),
        "haninge": CLLocationCoordinate2D(latitude: 59.1690, longitude: 18.1400),
        "tyresö": CLLocationCoordinate2D(latitude: 59.2444, longitude: 18.2295),
        "upplands väsby": CLLocationCoordinate2D(latitude: 59.5186, longitude: 17.9113),
        "vallentuna": CLLocationCoordinate2D(latitude: 59.5344, longitude: 18.0772),
        "österåker": CLLocationCoordinate2D(latitude: 59.4794, longitude: 18.2986),
        "värmdö": CLLocationCoordinate2D(latitude: 59.3275, longitude: 18.3882),
        "ekerö": CLLocationCoordinate2D(latitude: 59.2903, longitude: 17.8105),
        "salem": CLLocationCoordinate2D(latitude: 59.2006, longitude: 17.7694),
        "sigtuna": CLLocationCoordinate2D(latitude: 59.6170, longitude: 17.7230),
        "södertälje": CLLocationCoordinate2D(latitude: 59.1955, longitude: 17.6252),
        "norrtälje": CLLocationCoordinate2D(latitude: 59.7580, longitude: 18.7050),
        "nynäshamn": CLLocationCoordinate2D(latitude: 58.9039, longitude: 17.9479),
        "upplands-bro": CLLocationCoordinate2D(latitude: 59.5178, longitude: 17.6508),
        "nykvarn": CLLocationCoordinate2D(latitude: 59.1764, longitude: 17.4336),
        "göteborg": CLLocationCoordinate2D(latitude: 57.7089, longitude: 11.9746),
        "malmö": CLLocationCoordinate2D(latitude: 55.6050, longitude: 13.0038),
        "uppsala": CLLocationCoordinate2D(latitude: 59.8586, longitude: 17.6389),
        "västerås": CLLocationCoordinate2D(latitude: 59.6099, longitude: 16.5448),
        "örebro": CLLocationCoordinate2D(latitude: 59.2753, longitude: 15.2134),
        "linköping": CLLocationCoordinate2D(latitude: 58.4108, longitude: 15.6214),
        "helsingborg": CLLocationCoordinate2D(latitude: 56.0465, longitude: 12.6945),
        "jönköping": CLLocationCoordinate2D(latitude: 57.7826, longitude: 14.1618),
        "norrköping": CLLocationCoordinate2D(latitude: 58.5877, longitude: 16.1924),
        "lund": CLLocationCoordinate2D(latitude: 55.7047, longitude: 13.1910),
        "umeå": CLLocationCoordinate2D(latitude: 63.8258, longitude: 20.2630),
        "gävle": CLLocationCoordinate2D(latitude: 60.6749, longitude: 17.1413),
        "borås": CLLocationCoordinate2D(latitude: 57.7210, longitude: 12.9401),
        "eskilstuna": CLLocationCoordinate2D(latitude: 59.3706, longitude: 16.5077),
        "halmstad": CLLocationCoordinate2D(latitude: 56.6745, longitude: 12.8578),
        "växjö": CLLocationCoordinate2D(latitude: 56.8777, longitude: 14.8091),
        "karlstad": CLLocationCoordinate2D(latitude: 59.4022, longitude: 13.5115),
        "sundsvall": CLLocationCoordinate2D(latitude: 62.3908, longitude: 17.3069),
        "östersund": CLLocationCoordinate2D(latitude: 63.1767, longitude: 14.6361),
        "trollhättan": CLLocationCoordinate2D(latitude: 58.2837, longitude: 12.2886),
        "luleå": CLLocationCoordinate2D(latitude: 65.5848, longitude: 22.1567),
        "falun": CLLocationCoordinate2D(latitude: 60.6036, longitude: 15.6256),
        "karlskrona": CLLocationCoordinate2D(latitude: 56.1612, longitude: 15.5869),
        "skövde": CLLocationCoordinate2D(latitude: 58.3903, longitude: 13.8461),
        "kristianstad": CLLocationCoordinate2D(latitude: 56.0294, longitude: 14.1567),
        "kalmar": CLLocationCoordinate2D(latitude: 56.6634, longitude: 16.3568),
        "visby": CLLocationCoordinate2D(latitude: 57.6348, longitude: 18.2948)
    ]

    /// Resolves the actual geographical coordinates for an event based on its municipality and summary text,
    /// overcoming Polisen API's limitation of only returning county-center GPS.
    private static func resolveCoordinate(for event: PoliceEventDTO) -> (coordinate: CLLocationCoordinate2D, displayName: String) {
        let nameParts = event.name.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let rawMunicipality = nameParts.count >= 2 ? nameParts.last ?? "" : ""
        let municipalityKey = rawMunicipality.lowercased()
        let summaryLower = event.summary.lowercased()
        let nameLower = event.name.lowercased()

        // 1. Check if a specific neighborhood or district is mentioned in the summary or name
        for district in districtCoordinates {
            if summaryLower.contains(district.keyword) || nameLower.contains(district.keyword) {
                let jittered = addDeterministicJitter(to: district.coord, id: event.id)
                return (jittered, district.display)
            }
        }

        // 2. Check municipality name in known locations
        if let baseCoord = municipalityCoordinates[municipalityKey] {
            let jittered = addDeterministicJitter(to: baseCoord, id: event.id)
            let capitalizedName = rawMunicipality.prefix(1).uppercased() + rawMunicipality.dropFirst()
            return (jittered, capitalizedName)
        }

        // 3. Fallback: Parse Polisen's county-level GPS string
        let gpsParts = event.location.gps.split(separator: ",")
        if gpsParts.count == 2,
           let lat = Double(gpsParts[0].trimmingCharacters(in: .whitespaces)),
           let lon = Double(gpsParts[1].trimmingCharacters(in: .whitespaces)) {
            let base = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let jittered = addDeterministicJitter(to: base, id: event.id)
            return (jittered, rawMunicipality.isEmpty ? event.location.name : rawMunicipality)
        }

        // Default to Central Stockholm if parsing fails
        let defaultCoord = CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649)
        return (addDeterministicJitter(to: defaultCoord, id: event.id), "Stockholm")
    }

    /// Adds a tiny deterministic micro-offset (~100-200m) so multiple pins in the same area don't overlap completely
    private static func addDeterministicJitter(to coord: CLLocationCoordinate2D, id: Int) -> CLLocationCoordinate2D {
        let latJitter = (Double((abs(id * 17) % 21)) - 10.0) * 0.00018
        let lonJitter = (Double((abs(id * 31) % 21)) - 10.0) * 0.00032
        return CLLocationCoordinate2D(
            latitude: coord.latitude + latJitter,
            longitude: coord.longitude + lonJitter
        )
    }

    /// Fetches recent events from Polisen.se, filtering for:
    /// - Past 48 hours
    /// - Within 50 km of referenceLocation (or Central Stockholm if reference location is outside Sweden)
    static func fetchRecentEvents(near referenceLocation: CLLocation) async -> [Incident] {
        // Guard against Simulator/device default locations outside Sweden (e.g. Cupertino/San Francisco: lat 37.78)
        let isWithinSweden = referenceLocation.coordinate.latitude >= 55.0 &&
                             referenceLocation.coordinate.latitude <= 70.0 &&
                             referenceLocation.coordinate.longitude >= 10.0 &&
                             referenceLocation.coordinate.longitude <= 25.0
        let effectiveCenter = isWithinSweden
            ? referenceLocation
            : CLLocation(latitude: 59.3326, longitude: 18.0649)

        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 12
        request.setValue("IncidentTracker-iOS/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Polisen API HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return []
            }

            let events = try JSONDecoder().decode([PoliceEventDTO].self, from: data)
            return processEvents(events, near: effectiveCenter)
        } catch {
            print("Failed to fetch Polisen events from network (\(error.localizedDescription)).")
            return []
        }
    }

    /// Processes raw Polisen event DTOs into localized Incident models
    private static func processEvents(_ events: [PoliceEventDTO], near referenceLocation: CLLocation) -> [Incident] {
        let cutoffDate = Date().addingTimeInterval(-48 * 60 * 60) // Past 48 hours
        var incidents: [Incident] = []

        for event in events {
            // Filter 1: Date in past 48 hours
            guard let eventDate = parseDate(event.datetime),
                  eventDate >= cutoffDate else {
                continue
            }

            // Filter 2: Skip purely administrative notices
            let typeLower = event.type.lowercased()
            let summaryLower = event.summary.lowercased()
            if typeLower.contains("sammanfattning") ||
               typeLower == "information" ||
               summaryLower.contains("presstalesperson") ||
               summaryLower.contains("regionalt mediecenter") ||
               summaryLower.contains("inga händelser att rapportera") {
                continue
            }

            // Filter 3: Resolve geographical coordinates and check proximity within 50 km
            let (resolvedCoord, displayLocation) = resolveCoordinate(for: event)
            let eventLocation = CLLocation(latitude: resolvedCoord.latitude, longitude: resolvedCoord.longitude)
            let distanceInMeters = referenceLocation.distance(from: eventLocation)

            guard distanceInMeters <= 50_000 else { // 50 km covers entire metropolitan region
                continue
            }

            // Filter 4: Category classification (ignore events not belonging to predefined categories)
            guard let category = categorize(type: event.type, name: event.name, summary: event.summary) else {
                continue
            }
            let severity = determineSeverity(type: event.type, summary: event.summary)

            let fullDetails = """
            \(event.summary)

            Källa: Polisen.se (\(event.location.name))
            Läs mer: https://polisen.se\(event.url)
            """

            let incident = Incident(
                externalId: "polisen-\(event.id)",
                isPoliceReport: true,
                title: "\(event.type) (\(displayLocation))",
                details: fullDetails,
                latitude: resolvedCoord.latitude,
                longitude: resolvedCoord.longitude,
                category: category,
                severity: severity,
                timestamp: eventDate,
                reportedBy: "Polisen"
            )

            incidents.append(incident)
        }

        return incidents
    }

    /// Synchronizes recent police events into SwiftData
    @MainActor
    static func syncWithDatabase(
        modelContext: ModelContext,
        referenceLocation: CLLocation,
        force: Bool = false
    ) async {
        // Concurrency & rate-limiting debounce guard (avoid redundant requests within 15 seconds)
        if isSyncing { return }
        if !force, let lastSync = lastSyncDate, Date().timeIntervalSince(lastSync) < 15 {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        let recentPoliceIncidents = await fetchRecentEvents(near: referenceLocation)
        guard !recentPoliceIncidents.isEmpty else { return }

        // Fetch existing incidents to update existing or insert new ones
        let descriptor = FetchDescriptor<Incident>()
        guard let allExisting = try? modelContext.fetch(descriptor) else { return }

        // Clean up any previously stored police incidents with .other category
        var removedCount = 0
        for item in allExisting where item.isPoliceReport && item.category == .other {
            modelContext.delete(item)
            removedCount += 1
        }

        var existingMap: [String: Incident] = [:]
        for item in allExisting {
            if let extId = item.externalId {
                existingMap[extId] = item
            }
        }

        var addedCount = 0
        var updatedCount = 0

        for incident in recentPoliceIncidents {
            if let extId = incident.externalId {
                if let existing = existingMap[extId] {
                    // Update location and details if coordinates were previously at county centroid
                    let oldLoc = CLLocation(latitude: existing.latitude, longitude: existing.longitude)
                    let newLoc = CLLocation(latitude: incident.latitude, longitude: incident.longitude)
                    if oldLoc.distance(from: newLoc) > 100 || existing.title != incident.title {
                        existing.latitude = incident.latitude
                        existing.longitude = incident.longitude
                        existing.title = incident.title
                        existing.details = incident.details
                        existing.category = incident.category
                        existing.severity = incident.severity
                        updatedCount += 1
                    }
                } else {
                    modelContext.insert(incident)
                    addedCount += 1
                }
            }
        }

        if addedCount > 0 || updatedCount > 0 || removedCount > 0 {
            try? modelContext.save()
            print("Successfully synced Swedish Police events: \(addedCount) added, \(updatedCount) updated, \(removedCount) obsolete removed.")
            lastSyncDate = Date()
        }
    }

    // MARK: - Classification Helpers
    private static func categorize(type: String, name: String, summary: String) -> IncidentCategory? {
        let combinedText = "\(type) \(name) \(summary)".lowercased()

        // Transit check
        let transitKeywords = ["tunnelbana", "t-bana", "pendeltåg", "perrong", "tågstation", "spår", "buss", "hållplats", "trafikolycka", "trafikhinder"]
        if transitKeywords.contains(where: { combinedText.contains($0) }) {
            return .transitHazard
        }

        // Stalking / being followed
        if combinedText.contains("förfölj") || combinedText.contains("skuggad") || combinedText.contains("efterfölj") {
            return .stalking
        }

        // Violent crimes / assault
        let assaultKeywords = ["misshandel", "bråk", "mord", "dråp", "rån", "slagsmål", "våld/hot", "kroppsskada"]
        if assaultKeywords.contains(where: { combinedText.contains($0) }) {
            return .assault
        }

        // Harassment & sexual offences
        let harassmentKeywords = ["ofredande", "sexualbrott", "våldtäkt", "olaga hot", "antasta", "tafsad"]
        if harassmentKeywords.contains(where: { combinedText.contains($0) }) {
            return .harassment
        }

        // Weapons, drugs, burglary, theft
        let suspiciousKeywords = ["kniv", "vapen", "farligt föremål", "smällar", "narkotika", "fylleri", "inbrott", "stöld", "intrång"]
        if suspiciousKeywords.contains(where: { combinedText.contains($0) }) {
            return .suspiciousPresence
        }

        return nil
    }

    private static func determineSeverity(type: String, summary: String) -> IncidentSeverity {
        let combined = "\(type) \(summary)".lowercased()
        let highThreats = ["mord", "dråp", "våldtäkt", "rån", "grov", "kniv", "vapen", "farligt föremål", "skott", "mordbrand"]
        if highThreats.contains(where: { combined.contains($0) }) {
            return .high
        }

        let mediumThreats = ["misshandel", "bråk", "ofredande", "sexualbrott", "hot", "smällar", "narkotika", "stöld", "inbrott", "brand"]
        if mediumThreats.contains(where: { combined.contains($0) }) {
            return .medium
        }

        return .low
    }
}
