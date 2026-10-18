import Foundation
import CoreLocation
import SwiftUI

enum SafeHavenCategory: String, CaseIterable, Identifiable, Sendable {
    case convenienceStore = "Convenience Store"
    case pharmacy = "Late Pharmacy"
    case policeStation = "Police Station"
    case transitHub = "Staffed Transit Hub"
    case hospital = "Hospital & Emergency"

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
        }
    }
}

struct SafeHaven: Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: SafeHavenCategory
    let coordinate: CLLocationCoordinate2D
    let address: String
    let isOpen24Hours: Bool
    let note: String

    init(
        id: UUID = UUID(),
        name: String,
        category: SafeHavenCategory,
        coordinate: CLLocationCoordinate2D,
        address: String,
        isOpen24Hours: Bool = true,
        note: String = "Staffed / Well-lit haven"
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.coordinate = coordinate
        self.address = address
        self.isOpen24Hours = isOpen24Hours
        self.note = note
    }
}
