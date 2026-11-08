import Foundation
import CoreLocation

/// A safety-related SL disruption (police operation, people on the tracks, evacuation…) placed at the stop it affects.
nonisolated struct TransitSafetyAlert: Identifiable, Hashable, Sendable {
    /// One alert per disruption and stop: "<deviation case id>-<site id>"
    let id: String
    let caseID: Int
    let stopName: String
    let coordinate: CLLocationCoordinate2D
    let header: String
    let details: String
    /// SL's short description of what is affected, e.g. "Tunnelbana 13, 14"
    let affectedLines: String?
    let modes: [TransitMode]
    let severity: IncidentSeverity
    let reportedAt: Date

    /// Key used when the user marks this alert as over; shared by every stop the disruption covers.
    var ignoreKey: String { "sl-\(caseID)" }

    var primaryMode: TransitMode? { modes.first }

    static func == (lhs: TransitSafetyAlert, rhs: TransitSafetyAlert) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// How serious a disruption message is for the traveller's safety, or nil when it isn't safety-related
    /// (road works, lifts, moved stops). SL writes its messages in Swedish.
    static func severity(forMessage text: String) -> IncidentSeverity? {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "sv_SE"))
        if highKeywords.contains(where: normalized.contains) { return .high }
        if mediumKeywords.contains(where: normalized.contains) { return .medium }
        if lowKeywords.contains(where: normalized.contains) { return .low }
        return nil
    }

    // Diacritic-free, lowercase stems
    private static let highKeywords = [
        "polis", "skottlossning", "skjutning", "bomb", "misstankt foremal", "vapen", "knivhot", "hot mot",
        "utrymning", "utrymd", "brand i", "rokutveckling"
    ]
    private static let mediumKeywords = [
        "obehorig", "person i spar", "personer i spar", "sparspring", "sabotage", "brak", "slagsmal",
        "ordningsstorning", "ordningsvakt", "storande", "valdsam", "raddningstjanst"
    ]
    private static let lowKeywords = [
        "skadegorelse", "klotter", "stenkastning", "nedskrapning"
    ]
}
