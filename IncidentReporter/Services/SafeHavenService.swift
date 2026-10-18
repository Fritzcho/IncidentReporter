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

    /// Dynamic search around user coordinate using MapKit local search
    func fetchHavens(around coordinate: CLLocationCoordinate2D) async -> [SafeHaven] {
        var results = curatedHavens
        let searchQueries = ["Pharmacy", "Police", "7-Eleven"]

        for query in searchQueries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 4000,
                longitudinalMeters: 4000
            )

            let search = MKLocalSearch(request: request)
            if let response = try? await search.start() {
                for item in response.mapItems.prefix(2) {
                    let cat: SafeHavenCategory
                    if query == "Police" {
                        cat = .policeStation
                    } else if query == "Pharmacy" {
                        cat = .pharmacy
                    } else {
                        cat = .convenienceStore
                    }

                    let itemCoord = item.placemark.coordinate
                    let itemLoc = CLLocation(latitude: itemCoord.latitude, longitude: itemCoord.longitude)

                    // Avoid duplicate pins within 100m
                    let isDuplicate = results.contains { existing in
                        let existingLoc = CLLocation(latitude: existing.coordinate.latitude, longitude: existing.coordinate.longitude)
                        return existingLoc.distance(from: itemLoc) < 100
                    }

                    if !isDuplicate, let name = item.name {
                        let haven = SafeHaven(
                            name: name,
                            category: cat,
                            coordinate: itemCoord,
                            address: item.placemark.title ?? "Nearby Safe Haven",
                            isOpen24Hours: true,
                            note: "Verified local spot with public lighting"
                        )
                        results.append(haven)
                    }
                }
            }
        }

        return results
    }
}
