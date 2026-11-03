import Foundation
import CoreLocation
import SwiftUI

enum SafeHavenCategory: String, CaseIterable, Identifiable, Sendable {
    case convenienceStore = "Convenience Store"
    case pharmacy = "Pharmacy"
    case policeStation = "Police Station"
    case transitHub = "Staffed Transit Hub"
    case hospital = "Hospital & Emergency"
    case hotel = "Hotel Reception"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .convenienceStore:
            return "storefront.fill"
        case .pharmacy:
            return "cross.case.fill"
        case .policeStation:
            return "shield.fill"
        case .transitHub:
            return "tram.fill"
        case .hospital:
            return "cross.fill"
        case .hotel:
            return "bed.double.fill"
        }
    }

    var color: Color {
        switch self {
        case .convenienceStore:
            return .teal
        case .pharmacy:
            return .green
        case .policeStation:
            return .blue
        case .transitHub:
            return .indigo
        case .hospital:
            return .mint
        case .hotel:
            return .purple
        }
    }
}

/// Where a safe haven's details come from, shown so the user knows how far to trust them.
enum SafeHavenSource: String, Sendable {
    case curated = "Checked by IncidentTracker"
    case openStreetMap = "OpenStreetMap"
    case appleMaps = "Apple Maps"
}

struct SafeHaven: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: SafeHavenCategory
    let coordinate: CLLocationCoordinate2D
    let address: String
    let isOpen24Hours: Bool
    let note: String
    /// OpenStreetMap-style hours, e.g. "Mo-Fr 07:00-23:00; Sa,Su 08:00-22:00"; nil when unknown
    var openingHoursText: String?
    var source: SafeHavenSource = .curated

    var openingHours: OpeningHours? {
        openingHoursText.flatMap(OpeningHours.init)
    }

    /// true/false when the hours are known, nil when nobody has checked them
    func isOpen(at date: Date = .now) -> Bool? {
        if isOpen24Hours { return true }
        return openingHours?.isOpen(at: date)
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: SafeHavenCategory,
        coordinate: CLLocationCoordinate2D,
        address: String,
        isOpen24Hours: Bool = true,
        note: String = "Staffed / Well-lit haven",
        openingHoursText: String? = nil,
        source: SafeHavenSource = .curated
    ) {
        self.openingHoursText = openingHoursText
        self.source = source
        self.id = id
        self.name = name
        self.category = category
        self.coordinate = coordinate
        self.address = address
        self.isOpen24Hours = isOpen24Hours
        self.note = note
    }
}
