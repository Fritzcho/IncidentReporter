import Foundation
import CoreLocation
import MapKit

final class SafeHavenService: Sendable {
    static let shared = SafeHavenService()

    private init() {}

    /// Curated well-known safe havens in Central Stockholm & major transit hubs
    let curatedHavens: [SafeHaven] = [
        SafeHaven(
            name: "Apoteket C.W. Scheele (24h Night Pharmacy)",
            category: .pharmacy,
            coordinate: CLLocationCoordinate2D(latitude: 59.3332, longitude: 18.0560),
            address: "Klarabergsgatan 64, Stockholm",
            isOpen24Hours: true,
            note: "Sweden's designated 24/7 emergency night pharmacy. Always staffed, secure, and lit."
        ),
        SafeHaven(
            name: "7-Eleven Vasagatan (24h)",
            category: .convenienceStore,
            coordinate: CLLocationCoordinate2D(latitude: 59.3312, longitude: 18.0578),
            address: "Vasagatan 24, Stockholm",
            isOpen24Hours: true,
            note: "Open 24/7 with continuous staff presence outside Central Station."
        ),
        SafeHaven(
            name: "T-Centralen Metro Security Office",
            category: .transitHub,
            coordinate: CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649),
            address: "Sergels torg / T-Centralen, Stockholm",
            isOpen24Hours: true,
            note: "Manned SL Security checkpoint and customer service desk."
        ),
        SafeHaven(
            name: "Norrmalm Police Station",
            category: .policeStation,
            coordinate: CLLocationCoordinate2D(latitude: 59.3400, longitude: 18.0465),
            address: "Torsgatan 26, Stockholm",
            isOpen24Hours: true,
            note: "Official police reception with immediate emergency intercom."
        ),
        SafeHaven(
            name: "7-Eleven Medborgarplatsen (24h)",
            category: .convenienceStore,
            coordinate: CLLocationCoordinate2D(latitude: 59.3145, longitude: 18.0722),
            address: "Götgatan 67, Södermalm",
            isOpen24Hours: true,
            note: "Continuous lighting and active street presence on Södermalm."
        ),
        SafeHaven(
            name: "Södersjukhuset Emergency (Akuten)",
            category: .hospital,
            coordinate: CLLocationCoordinate2D(latitude: 59.3094, longitude: 18.0565),
            address: "Sjukhusbacken 10, Stockholm",
            isOpen24Hours: true,
            note: "24/7 Hospital emergency entrance with 24/7 security reception."
        ),
        SafeHaven(
            name: "Pressbyrån Odenplan Metro",
            category: .convenienceStore,
            coordinate: CLLocationCoordinate2D(latitude: 59.3431, longitude: 18.0495),
            address: "Karlbergsvägen 1, Stockholm",
            isOpen24Hours: false,
            note: "Late-night staffed shop at the main Odenplan commuter entrance."
        )
    ]

    /// Safe havens around a coordinate: the curated list, OpenStreetMap (with opening hours) and
    /// Apple Maps searches for staffed chains, merged so each place appears once.
    func fetchHavens(around coordinate: CLLocationCoordinate2D) async -> [SafeHaven] {
        async let fromOSM = OSMSafeHavenService.shared.havens(around: coordinate)
        async let fromAppleMaps = appleMapsHavens(around: coordinate)
        return Self.merged(curatedHavens + (await fromOSM) + (await fromAppleMaps))
    }

    /// Searches for police, pharmacies and chains that are usually staffed late. Apple doesn't give
    /// opening hours here, so these are shown as "hours not verified".
    private func appleMapsHavens(around coordinate: CLLocationCoordinate2D) async -> [SafeHaven] {
        let searches: [(query: String, category: SafeHavenCategory)] = [
            ("Police", .policeStation),
            ("Pharmacy", .pharmacy),
            ("Akutmottagning", .hospital),
            ("7-Eleven", .convenienceStore),
            ("Pressbyrån", .convenienceStore),
            ("Circle K", .convenienceStore),
            ("Hotel", .hotel)
        ]
        return await withTaskGroup(of: [SafeHaven].self) { group in
            for search in searches {
                group.addTask {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = search.query
                    request.resultTypes = .pointOfInterest
                    request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 4000, longitudinalMeters: 4000)
                    guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
                    return response.mapItems.prefix(10).compactMap { item in
                        guard let name = item.name else { return nil }
                        return SafeHaven(
                            name: name,
                            category: search.category,
                            coordinate: item.location.coordinate,
                            address: item.address?.shortAddress ?? String(localized: "Address not listed"),
                            isOpen24Hours: false,
                            note: String(localized: "Usually staffed. Check that it's open before relying on it."),
                            source: .appleMaps
                        )
                    }
                }
            }
            var all: [SafeHaven] = []
            for await havens in group {
                all += havens
            }
            return all
        }
    }

    /// One pin per place: the same kind of place within 60 m counts as a duplicate. The entry with
    /// the most trustworthy details wins (curated, then OpenStreetMap with hours, then the rest).
    static func merged(_ havens: [SafeHaven]) -> [SafeHaven] {
        func rank(_ haven: SafeHaven) -> Int {
            switch haven.source {
            case .curated: return 0
            case .openStreetMap: return haven.openingHours == nil ? 2 : 1
            case .appleMaps: return 3
            }
        }
        var result: [SafeHaven] = []
        for haven in havens.sorted(by: { rank($0) < rank($1) }) {
            let location = CLLocation(latitude: haven.coordinate.latitude, longitude: haven.coordinate.longitude)
            let isDuplicate = result.contains { existing in
                existing.category == haven.category
                    && CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                        .distance(from: location) < 60
            }
            if !isDuplicate {
                result.append(haven)
            }
        }
        return result
    }
}
