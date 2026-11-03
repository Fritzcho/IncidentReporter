import Foundation
import CoreLocation
import MapKit
import SwiftUI

/// A place the user has saved: their home, a temporary home or a shortcut such as "Work".
struct SavedPlace: Codable, Identifiable, Hashable {
    var id = UUID()
    /// The user's own label, e.g. "Home", "Anna's place" or "Work"
    var label: String
    var address: String
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// For routing: named with the user's label so the route card reads "Safe route to Home"
    var mapItem: MKMapItem {
        let item = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
        item.name = label
        return item
    }

    init(label: String, address: String, coordinate: CLLocationCoordinate2D) {
        self.label = label
        self.address = address
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

/// Somewhere the user sleeps instead of home for a while (e.g. at a friend's). Replaces Home
/// as the "take me home" destination until `until`, then Home applies again by itself.
struct TemporaryHome: Codable, Hashable {
    var place: SavedPlace
    var until: Date

    var isActive: Bool { until > .now }
}

/// Someone the user trusts to be alerted, e.g. by the safety timer.
struct TrustedContact: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var phone: String
}

/// How much extra walking the user accepts to avoid reported dangers.
enum RouteCaution: String, CaseIterable, Identifiable {
    case fastest
    case balanced
    case careful

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .fastest: return "Fastest"
        case .balanced: return "Balanced"
        case .careful: return "Careful"
        }
    }

    var explanation: LocalizedStringKey {
        switch self {
        case .fastest: return "Only small detours around recent, serious dangers."
        case .balanced: return "A few minutes extra to avoid most recent dangers."
        case .careful: return "Longer detours to keep well away from any reported danger."
        }
    }

    /// Multiplies each danger's time penalty when routes are compared
    var penaltyWeight: Double {
        switch self {
        case .fastest: return 0.5
        case .balanced: return 1
        case .careful: return 2.5
        }
    }
}

/// Which way of travelling a new route starts with.
enum PreferredTravelMode: String, CaseIterable, Identifiable {
    /// Public transport when it's clearly faster, otherwise walking
    case automatic
    case walk
    case transit

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .automatic: return "Fastest option"
        case .walk: return "Walk"
        case .transit: return "Public transport"
        }
    }
}
