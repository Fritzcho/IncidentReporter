import Foundation
import Observation

/// The user's home, temporary home, saved places and trusted contacts. Stored on this device only.
@Observable
final class MyPlacesStore {
    static let shared = MyPlacesStore()

    private struct Snapshot: Codable {
        var home: SavedPlace?
        var temporaryHome: TemporaryHome?
        var places: [SavedPlace] = []
        var contacts: [TrustedContact] = []
    }

    private static let defaultsKey = "myPlaces.v1"
    // Read by the safety timer, which predates this store
    private static let legacyContactNameKey = "emergencyContactName"
    private static let legacyContactPhoneKey = "emergencyContactPhone"

    var home: SavedPlace? { didSet { save() } }
    var temporaryHome: TemporaryHome? { didSet { save() } }
    var places: [SavedPlace] = [] { didSet { save() } }
    var contacts: [TrustedContact] = [] { didSet { save() } }

    private init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.defaultsKey),
           let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            home = snapshot.home
            temporaryHome = snapshot.temporaryHome
            places = snapshot.places
            contacts = snapshot.contacts
        } else if let phone = defaults.string(forKey: Self.legacyContactPhoneKey), !phone.isEmpty {
            // Bring over the single emergency contact from the old Settings page
            contacts = [TrustedContact(name: defaults.string(forKey: Self.legacyContactNameKey) ?? "", phone: phone)]
        }
    }

    /// The temporary home while it lasts
    var activeTemporaryHome: TemporaryHome? {
        guard let temporaryHome, temporaryHome.isActive else { return nil }
        return temporaryHome
    }

    /// Where "take me home" goes: the temporary home while it lasts, otherwise Home
    var effectiveHome: SavedPlace? {
        activeTemporaryHome?.place ?? home
    }

    /// Home first, then the other saved places, for shortcuts in the route search
    var routeShortcuts: [SavedPlace] {
        [effectiveHome].compactMap { $0 } + places
    }

    func removeAll() {
        home = nil
        temporaryHome = nil
        places = []
        contacts = []
    }

    private func save() {
        let snapshot = Snapshot(home: home, temporaryHome: temporaryHome, places: places, contacts: contacts)
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
        // The safety timer alerts the first trusted contact
        defaults.set(contacts.first?.name ?? "", forKey: Self.legacyContactNameKey)
        defaults.set(contacts.first?.phone ?? "", forKey: Self.legacyContactPhoneKey)
    }
}
