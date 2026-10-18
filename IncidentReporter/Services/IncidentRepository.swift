import Foundation
import SwiftData
import CoreLocation

/// Protocol abstracting safety incident storage.
/// Allows transitioning from local SwiftData storage to a REST / GraphQL backend in the future without modifying UI views.
protocol IncidentRepository: Sendable {
    func fetchIncidents() async throws -> [Incident]
    func addIncident(_ incident: Incident) async throws
    func deleteIncident(id: UUID) async throws
}

// MARK: - Sample Personal Safety Data in Central Stockholm
enum SampleIncidents {
    /// Central Stockholm reference coordinates (T-Centralen / Sergels torg)
    static let stockholmCenter = CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649)

    static func createSampleIncidents(around center: CLLocationCoordinate2D = stockholmCenter) -> [Incident] {
        [
            Incident(
                title: "Person following solo commuters from T-Centralen exit",
                details: "Individual in dark coat followed me from the Vasagatan station exit up towards Klarabergsgatan. Ducked into 7-Eleven. Be mindful of your surroundings.",
                latitude: 59.3308,
                longitude: 18.0585,
                category: .stalking,
                severity: .high,
                reportedBy: "Anonymous"
            ),
            Incident(
                title: "Drink tampering warning at Stureplan venue",
                details: "Spike alert reported tonight near venue entrance on Kungsgatan. Watch your drinks closely and never leave glasses unattended.",
                latitude: 59.3364,
                longitude: 18.0729,
                category: .drinkSpiking,
                severity: .high,
                reportedBy: "Anonymous"
            ),
            Incident(
                title: "Dark unlit alley & broken street lanterns in Gamla Stan",
                details: "Multiple historical lanterns out along the narrow pedestrian passage. Very dark with zero visibility. Walk along the open waterfront instead.",
                latitude: 59.3248,
                longitude: 18.0702,
                category: .poorLighting,
                severity: .medium,
                reportedBy: "Anonymous"
            ),
            Incident(
                title: "Aggressive shouting & catcalling near Medborgarplatsen",
                details: "Group yelling intimidating comments at women walking towards the metro entrance. Stick to the well-lit side near Folkungagatan.",
                latitude: 59.3149,
                longitude: 18.0716,
                category: .harassment,
                severity: .medium,
                reportedBy: "Anonymous"
            ),
            Incident(
                title: "Hostile altercation on Odenplan green line platform",
                details: "Aggressive fight broke out on the northbound platform. SL security guards alerted. Stay near station booth or middle train cars.",
                latitude: 59.3429,
                longitude: 18.0498,
                category: .transitHazard,
                severity: .high,
                reportedBy: "Anonymous"
            )
        ]
    }
}
