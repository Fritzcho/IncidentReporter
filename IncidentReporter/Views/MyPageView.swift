import SwiftUI
import SwiftData

/// The user's own page: home and temporary home, saved places, trusted contacts, how routes and
/// alerts behave, privacy, and the app settings. Everything here stays on this device.
struct MyPageView: View {
    private enum ActiveSheet: Identifiable {
        case home
        case temporaryHome
        case place(SavedPlace?)
        case contact(TrustedContact?)
        case settings

        var id: String {
            switch self {
            case .home: return "home"
            case .temporaryHome: return "temporaryHome"
            case .place(let place): return "place-\(place?.id.uuidString ?? "new")"
            case .contact(let contact): return "contact-\(contact?.id.uuidString ?? "new")"
            case .settings: return "settings"
            }
        }
    }

    @State private var store = MyPlacesStore.shared
    @State private var ignoredStore = IgnoredIncidentStore.shared
    @State private var activeSheet: ActiveSheet?
    @State private var isConfirmingRemoveAll = false

    @AppStorage("routeCaution") private var routeCaution: RouteCaution = .balanced
    @AppStorage("preferredTravelMode") private var preferredTravelMode: PreferredTravelMode = .automatic
    @AppStorage("proximityAlertsEnabled") private var proximityAlertsEnabled = true
    @AppStorage("proximityAlertDistance") private var proximityAlertDistance = 500.0
    @AppStorage("routeAlertsEnabled") private var routeAlertsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                placesSection
                contactsSection
                routesSection
                alertsSection
                privacySection

                Section {
                    Button {
                        activeSheet = .settings
                    } label: {
                        Label("Language, shake action & app settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("My page")
            .sheet(item: $activeSheet) { sheet in
                sheetContent(sheet)
            }
            .confirmationDialog("Remove all your places and contacts?", isPresented: $isConfirmingRemoveAll, titleVisibility: .visible) {
                Button("Remove all", role: .destructive) {
                    store.removeAll()
                }
            } message: {
                Text("Home, temporary home, saved places and trusted contacts are deleted from this phone.")
            }
        }
    }

    // MARK: - Sections

    private var placesSection: some View {
        Section {
            if let home = store.home {
                Button { activeSheet = .home } label: {
                    SavedPlaceRow(systemImage: "house.fill", title: home.label, address: home.address)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("Remove", role: .destructive) { store.home = nil }
                }
            } else {
                Button { activeSheet = .home } label: {
                    Label("Set home", systemImage: "house")
                }
            }

            if let temporary = store.activeTemporaryHome {
                Button { activeSheet = .temporaryHome } label: {
                    SavedPlaceRow(
                        systemImage: "moon.zzz.fill",
                        tint: .indigo,
                        title: temporary.place.label,
                        address: temporary.place.address,
                        detail: Text("Temporary home until \(temporary.until, format: .dateTime.weekday().hour().minute())")
                    )
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("End now", role: .destructive) { store.temporaryHome = nil }
                }
            } else {
                Button { activeSheet = .temporaryHome } label: {
                    Label("Add temporary home", systemImage: "moon.zzz")
                }
            }

            ForEach(store.places) { place in
                Button { activeSheet = .place(place) } label: {
                    SavedPlaceRow(systemImage: "mappin", tint: .orange, title: place.label, address: place.address)
                }
                .buttonStyle(.plain)
            }
            .onDelete { store.places.remove(atOffsets: $0) }

            Button { activeSheet = .place(nil) } label: {
                Label("Save another place", systemImage: "plus.circle")
            }
        } header: {
            Text("My places")
        } footer: {
            Text("Staying at a friend's? Add a temporary home and \"Take me home\" goes there until it ends.")
        }
    }

    private var contactsSection: some View {
        Section {
            ForEach(store.contacts) { contact in
                Button { activeSheet = .contact(contact) } label: {
                    TrustedContactRow(name: contact.name, phone: contact.phone, isPrimary: contact.id == store.contacts.first?.id)
                }
                .buttonStyle(.plain)
            }
            .onDelete { store.contacts.remove(atOffsets: $0) }
            .onMove { store.contacts.move(fromOffsets: $0, toOffset: $1) }

            Button { activeSheet = .contact(nil) } label: {
                Label("Add trusted contact", systemImage: "person.badge.plus")
            }
        } header: {
            Text("Trusted contacts")
        } footer: {
            Text("The first contact is alerted if your safety timer runs out.")
        }
    }

    private var routesSection: some View {
        Section {
            Picker("How careful", selection: $routeCaution) {
                ForEach(RouteCaution.allCases) { caution in
                    Text(caution.title).tag(caution)
                }
            }
            .pickerStyle(.segmented)

            Picker("Start with", selection: $preferredTravelMode) {
                ForEach(PreferredTravelMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } header: {
            Text("Safe routes")
        } footer: {
            Text(routeCaution.explanation)
        }
    }

    private var alertsSection: some View {
        Section {
            Toggle("Warn me near dangers", isOn: $proximityAlertsEnabled)
            if proximityAlertsEnabled {
                Picker("Warning distance", selection: $proximityAlertDistance) {
                    Text("200 m").tag(200.0)
                    Text("500 m").tag(500.0)
                    Text("1 km").tag(1000.0)
                }
            }
            Toggle("Changes on my route", isOn: $routeAlertsEnabled)
        } header: {
            Text("Alerts")
        } footer: {
            Text("Route alerts tell you when a new danger appears on the way and the route changes.")
        }
    }

    private var privacySection: some View {
        Section {
            HStack {
                Label("Dangers you've ignored", systemImage: "eye.slash")
                Spacer()
                Text("\(ignoredStore.keys.count)")
                    .foregroundStyle(.secondary)
            }
            if !ignoredStore.keys.isEmpty {
                Button("Warn me about all of them again") {
                    ignoredStore.restoreAll()
                }
            }
            Button("Remove all places and contacts", role: .destructive) {
                isConfirmingRemoveAll = true
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Your places, contacts and ignored dangers are only stored on this phone.")
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .home:
            PlacePickerSheet(purpose: .home, existing: store.home) { place, _ in
                store.home = place
            }
        case .temporaryHome:
            PlacePickerSheet(purpose: .temporaryHome, existing: store.activeTemporaryHome?.place,
                             until: store.activeTemporaryHome?.until) { place, until in
                store.temporaryHome = TemporaryHome(place: place, until: until ?? .now.addingTimeInterval(12 * 3600))
            }
        case .place(let existing):
            PlacePickerSheet(purpose: .place, existing: existing) { place, _ in
                if let index = store.places.firstIndex(where: { $0.id == place.id }) {
                    store.places[index] = place
                } else {
                    store.places.append(place)
                }
            }
        case .contact(let existing):
            TrustedContactSheet(contact: existing) { contact in
                if let index = store.contacts.firstIndex(where: { $0.id == contact.id }) {
                    store.contacts[index] = contact
                } else {
                    store.contacts.append(contact)
                }
            }
        case .settings:
            SettingsView()
        }
    }
}

/// Add or edit a trusted contact.
private struct TrustedContactSheet: View {
    let contact: TrustedContact?
    let onSave: (TrustedContact) -> Void
    @State private var name: String
    @State private var phone: String
    @Environment(\.dismiss) private var dismiss

    init(contact: TrustedContact?, onSave: @escaping (TrustedContact) -> Void) {
        self.contact = contact
        self.onSave = onSave
        _name = State(initialValue: contact?.name ?? "")
        _phone = State(initialValue: contact?.phone ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                EmergencyContactInputView(contactName: $name, contactPhone: $phone)
            }
            .navigationTitle(contact == nil ? "New contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = contact ?? TrustedContact(name: "", phone: "")
                        saved.name = name.trimmingCharacters(in: .whitespaces)
                        saved.phone = phone.trimmingCharacters(in: .whitespaces)
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(phone.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    MyPageView()
        .modelContainer(for: Incident.self, inMemory: true)
}
