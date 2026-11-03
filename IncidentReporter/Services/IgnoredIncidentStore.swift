import Foundation
import Observation

/// Dangers this user has marked as over. Stored only on this device: ignoring a danger never
/// removes it for anyone else. It only stops this user's proximity alerts and safe routes from reacting to it.
@Observable
final class IgnoredIncidentStore {
    static let shared = IgnoredIncidentStore()

    private static let defaultsKey = "ignoredIncidentKeys"

    private(set) var keys: Set<String>

    private init() {
        keys = Set(UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? [])
    }

    /// Police events get new local IDs when re-imported, so they're keyed by their police event ID
    static func key(for incident: Incident) -> String {
        incident.externalId ?? incident.id.uuidString
    }

    func isIgnored(_ incident: Incident) -> Bool {
        isIgnored(key: Self.key(for: incident))
    }

    func ignore(_ incident: Incident) {
        ignore(key: Self.key(for: incident))
    }

    func restore(_ incident: Incident) {
        restore(key: Self.key(for: incident))
    }

    /// For dangers that aren't stored incidents, such as SL safety alerts (see `TransitSafetyAlert.ignoreKey`)
    func isIgnored(key: String) -> Bool {
        keys.contains(key)
    }

    func ignore(key: String) {
        keys.insert(key)
        save()
    }

    func restore(key: String) {
        keys.remove(key)
        save()
    }

    /// Start warning about every ignored danger again
    func restoreAll() {
        keys.removeAll()
        save()
    }

    private func save() {
        UserDefaults.standard.set(Array(keys), forKey: Self.defaultsKey)
    }
}
