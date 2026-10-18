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

    /// Returns 14 realistic safety testing incidents across Central Stockholm and nearby transit hubs
    static func createSampleIncidents(around center: CLLocationCoordinate2D = stockholmCenter) -> [Incident] {
        let now = Date()

        return [
            Incident(
                externalId: "sample-stockholm-1",
                isPoliceReport: false,
                title: "Person following solo commuters from T-Centralen exit",
                details: "Individual in dark coat followed me from the Vasagatan station exit up towards Klarabergsgatan. Ducked into 7-Eleven. Be mindful of your surroundings.",
                latitude: 59.3308,
                longitude: 18.0585,
                category: .stalking,
                severity: .high,
                timestamp: now.addingTimeInterval(-30 * 60), // 30 mins ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-2",
                isPoliceReport: false,
                title: "Drink tampering warning at Stureplan venue",
                details: "Spike alert reported tonight near venue entrance on Kungsgatan. Watch your drinks closely and never leave glasses unattended.",
                latitude: 59.3364,
                longitude: 18.0729,
                category: .drinkSpiking,
                severity: .high,
                timestamp: now.addingTimeInterval(-1.5 * 3600), // 1.5 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-3",
                isPoliceReport: false,
                title: "Dark unlit alley & broken street lanterns in Gamla Stan",
                details: "Multiple historical lanterns out along the narrow pedestrian passage on Prästgatan. Very dark with zero visibility. Walk along the open waterfront instead.",
                latitude: 59.3248,
                longitude: 18.0702,
                category: .poorLighting,
                severity: .medium,
                timestamp: now.addingTimeInterval(-3.0 * 3600), // 3 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-4",
                isPoliceReport: false,
                title: "Aggressive catcalling & intimidation near Medborgarplatsen",
                details: "Group yelling intimidating comments at women walking towards the metro entrance. Stick to the well-lit side near Folkungagatan.",
                latitude: 59.3149,
                longitude: 18.0716,
                category: .harassment,
                severity: .medium,
                timestamp: now.addingTimeInterval(-45 * 60), // 45 mins ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-5",
                isPoliceReport: false,
                title: "Hostile altercation on Odenplan green line platform",
                details: "Aggressive fight broke out on the northbound platform. SL security guards alerted. Stay near station booth or middle train cars.",
                latitude: 59.3429,
                longitude: 18.0498,
                category: .transitHazard,
                severity: .high,
                timestamp: now.addingTimeInterval(-2.0 * 3600), // 2 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-6",
                isPoliceReport: false,
                title: "Aggressive harassment on pedestrian walkway near Slussen",
                details: "Man blocking passage up towards Götgatan, demanding money and grabbing arm of solo pedestrians. Avoid the wooden walkway stairs.",
                latitude: 59.3198,
                longitude: 18.0718,
                category: .harassment,
                severity: .medium,
                timestamp: now.addingTimeInterval(-1.0 * 3600), // 1 hour ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-7",
                isPoliceReport: false,
                title: "Suspicious group loitering in unlit park entrance at Tantolunden",
                details: "Group lingering in tree shadows by the Hornstull park archway, catcalling runners and following people closely. Stick to Hornsgatan sidewalk.",
                latitude: 59.3158,
                longitude: 18.0335,
                category: .suspiciousPresence,
                severity: .medium,
                timestamp: now.addingTimeInterval(-2.5 * 3600), // 2.5 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-8",
                isPoliceReport: false,
                title: "Escalator blockage & intimidation at Fridhemsplan metro",
                details: "Two intoxicated men blocking the upper escalator landing, harassing women as they step off. Ticket attendants and security notified.",
                latitude: 59.3325,
                longitude: 18.0305,
                category: .transitHazard,
                severity: .medium,
                timestamp: now.addingTimeInterval(-3.5 * 3600), // 3.5 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-9",
                isPoliceReport: false,
                title: "Unmarked dark car following pedestrian along Nybrogatan",
                details: "Dark sedan drove slowly alongside me for three blocks, rolling down the window repeatedly. Entered a brightly lit convenience store until they sped off.",
                latitude: 59.3358,
                longitude: 18.0782,
                category: .stalking,
                severity: .high,
                timestamp: now.addingTimeInterval(-20 * 60), // 20 mins ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-10",
                isPoliceReport: false,
                title: "Complete lighting failure on waterfront pathway below Västerbron",
                details: "All park lampposts along the water in Rålambshovsparken are out. Pitch black with uneven pavement and zero visibility. Stay on Norr Mälarstrand instead.",
                latitude: 59.3275,
                longitude: 18.0195,
                category: .poorLighting,
                severity: .low,
                timestamp: now.addingTimeInterval(-5.0 * 3600), // 5 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-11",
                isPoliceReport: false,
                title: "Physical fight outside restaurant at Sickla Udde tram stop",
                details: "Violent altercation broke out spilling onto the tram platform. Broken glass on the path. Police cars arriving on scene.",
                latitude: 59.3038,
                longitude: 18.1065,
                category: .assault,
                severity: .high,
                timestamp: now.addingTimeInterval(-1.2 * 3600), // 1.2 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-12",
                isPoliceReport: false,
                title: "Men photographing solo pedestrians outside cinema on Hötorget",
                details: "Two individuals taking non-consensual close-up photos of women walking towards Kungsgatan and following them to the subway.",
                latitude: 59.3355,
                longitude: 18.0625,
                category: .suspiciousPresence,
                severity: .low,
                timestamp: now.addingTimeInterval(-4.0 * 3600), // 4 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-13",
                isPoliceReport: false,
                title: "Suspected drink spiking report at bar near Skanstull",
                details: "Friend experienced sudden disorientation and motor loss shortly after leaving drink unattended at bar counter. Staff alerted, stay alert.",
                latitude: 59.3082,
                longitude: 18.0765,
                category: .drinkSpiking,
                severity: .high,
                timestamp: now.addingTimeInterval(-6.0 * 3600), // 6 hours ago
                reportedBy: "Anonymous"
            ),
            Incident(
                externalId: "sample-stockholm-14",
                isPoliceReport: false,
                title: "Confrontational youth group blocking walkway by Kista bus terminal",
                details: "Loud group blocking the covered walkway to the bus terminals, yelling profanities at women passing by alone. Security patrol requested.",
                latitude: 59.4030,
                longitude: 17.9440,
                category: .harassment,
                severity: .medium,
                timestamp: now.addingTimeInterval(-2.8 * 3600), // 2.8 hours ago
                reportedBy: "Anonymous"
            )
        ]
    }
}
