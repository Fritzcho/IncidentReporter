import Foundation
import SwiftData
import CoreLocation

@Model
final class Incident: Identifiable {
    var id: UUID = UUID()
    var externalId: String? = nil
    var isPoliceReport: Bool = false
    var title: String = ""
    var details: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    var categoryRaw: String = IncidentCategory.harassment.rawValue
    var severityRaw: String = IncidentSeverity.medium.rawValue
    var timestamp: Date = Date()
    var reportedBy: String = "Anonymous"

    var category: IncidentCategory {
        get { IncidentCategory(rawValue: categoryRaw) ?? .harassment }
        set { categoryRaw = newValue.rawValue }
    }

    var severity: IncidentSeverity {
        get { IncidentSeverity(rawValue: severityRaw) ?? .medium }
        set { severityRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var hoursAgo: Double {
        max(0, Date().timeIntervalSince(timestamp) / 3600.0)
    }

    var decayStatus: IncidentDecayStatus {
        if hoursAgo < IncidentTimeFilter.fourHours.hours {
            return .recent
        } else if hoursAgo < IncidentTimeFilter.twelveHours.hours {
            return .active
        } else if hoursAgo < IncidentTimeFilter.twentyFourHours.hours {
            return .aging
        } else {
            return .expired
        }
    }

    var isExpired: Bool {
        hoursAgo > 24
    }

    init(
        id: UUID = UUID(),
        externalId: String? = nil,
        isPoliceReport: Bool = false,
        title: String,
        details: String = "",
        latitude: Double,
        longitude: Double,
        category: IncidentCategory = .harassment,
        severity: IncidentSeverity = .medium,
        timestamp: Date = Date(),
        reportedBy: String = "Anonymous"
    ) {
        self.id = id
        self.externalId = externalId
        self.isPoliceReport = isPoliceReport
        self.title = title
        self.details = details
        self.latitude = latitude
        self.longitude = longitude
        self.categoryRaw = category.rawValue
        self.severityRaw = severity.rawValue
        self.timestamp = timestamp
        self.reportedBy = reportedBy
    }
}
