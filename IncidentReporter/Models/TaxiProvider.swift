import Foundation
import SwiftUI

/// A taxi company or ride-hailing app the user can contact from the map.
nonisolated struct TaxiProvider: Identifiable, Hashable, Sendable {
    enum Contact: Hashable, Sendable {
        /// Call a dispatch line. `display` is the number as printed by the company.
        case phone(display: String, e164: String)
        /// Open a ride-hailing app, falling back to `fallback` (App Store / web) if it is not installed.
        case app(url: URL, fallback: URL)
    }

    let id: String
    let name: String
    let contact: Contact
    let color: Color

    var primaryURL: URL {
        switch contact {
        case .phone(_, let e164): return URL(string: "tel:\(e164)")!
        case .app(let url, _): return url
        }
    }

    var fallbackURL: URL? {
        if case .app(_, let fallback) = contact { return fallback }
        return nil
    }

    var systemImage: String {
        switch contact {
        case .phone: return "phone.fill"
        case .app: return "app.badge.fill"
        }
    }

    /// Dispatch lines and apps that serve the Stockholm region.
    /// Numbers verified against each company's own website (taxistockholm.se, sverigetaxi.se, taxikurir.se).
    static let stockholm: [TaxiProvider] = [
        TaxiProvider(
            id: "taxi-stockholm",
            name: "Taxi Stockholm",
            contact: .phone(display: "08-15 00 00", e164: "+468150000"),
            color: .yellow
        ),
        TaxiProvider(
            id: "sverigetaxi",
            name: "Sverigetaxi",
            contact: .phone(display: "020-20 20 20", e164: "+4620202020"),
            color: .blue
        ),
        TaxiProvider(
            id: "taxi-kurir",
            name: "Taxi Kurir",
            contact: .phone(display: "0771-86 00 00", e164: "+46771860000"),
            color: .orange
        ),
        TaxiProvider(
            id: "uber",
            name: "Uber",
            contact: .app(
                url: URL(string: "uber://?action=setPickup&pickup=my_location")!,
                fallback: URL(string: "https://m.uber.com/ul/?action=setPickup&pickup=my_location")!
            ),
            color: .black
        ),
        TaxiProvider(
            id: "bolt",
            name: "Bolt",
            contact: .app(
                url: URL(string: "bolt://")!,
                fallback: URL(string: "https://apps.apple.com/app/id675033630")!
            ),
            color: .green
        )
    ]
}
