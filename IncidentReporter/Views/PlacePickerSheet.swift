import SwiftUI
import MapKit

/// Choose a place to save (Home, a temporary home or another place): search for an address or use
/// the current position, give it a name, and for a temporary home say until when.
struct PlacePickerSheet: View {
    enum Purpose {
        case home
        case temporaryHome
        case place

        var title: LocalizedStringKey {
            switch self {
            case .home: return "Set home"
            case .temporaryHome: return "Temporary home"
            case .place: return "Save a place"
            }
        }

        var defaultLabel: String {
            switch self {
            case .home: return String(localized: "Home")
            case .temporaryHome, .place: return ""
            }
        }
    }

    let purpose: Purpose
    var existing: SavedPlace?
    /// The chosen place, and for a temporary home the time it ends
    let onSave: (SavedPlace, Date?) -> Void

    @State private var label: String
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var chosen: SavedPlace?
    @State private var until: Date
    @State private var isSearching = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(purpose: Purpose, existing: SavedPlace? = nil, until: Date? = nil, onSave: @escaping (SavedPlace, Date?) -> Void) {
        self.purpose = purpose
        self.existing = existing
        self.onSave = onSave
        _label = State(initialValue: existing?.label ?? purpose.defaultLabel)
        _chosen = State(initialValue: existing)
        _until = State(initialValue: until ?? Self.tomorrowMorning)
    }

    /// Default end of a sleepover: 10:00 the next morning
    private static var tomorrowMorning: Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: .now) ?? .now
        return calendar.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    private var canSave: Bool {
        chosen != nil && !label.trimmingCharacters(in: .whitespaces).isEmpty && (purpose != .temporaryHome || until > .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField(purpose == .temporaryHome ? "e.g. Anna's place" : "e.g. Work", text: $label)
                }

                if purpose == .temporaryHome {
                    Section {
                        DatePicker("Until", selection: $until, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                    } footer: {
                        Text("Take me home goes here until then. After that it goes to your normal home again.")
                    }
                }

                Section("Address") {
                    if let chosen {
                        Label {
                            VStack(alignment: .leading) {
                                Text(chosen.address)
                                Text(String(format: "%.4f, %.4f", chosen.latitude, chosen.longitude))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    TextField("Search address or place", text: $query)
                        .autocorrectionDisabled()

                    Button {
                        Task { await useCurrentLocation() }
                    } label: {
                        Label("Use my current location", systemImage: "location.fill")
                    }

                    if isSearching {
                        ProgressView()
                    }
                    ForEach(results, id: \.self) { item in
                        Button {
                            choose(item)
                        } label: {
                            DestinationSearchRow(
                                name: item.name ?? String(localized: "Place"),
                                address: item.address?.shortAddress,
                                coordinate: item.location.coordinate,
                                userLocation: nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(purpose.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard var place = chosen else { return }
                        place.label = label.trimmingCharacters(in: .whitespaces)
                        onSave(place, purpose == .temporaryHome ? until : nil)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await search()
            }
        }
    }

    private func choose(_ item: MKMapItem) {
        chosen = SavedPlace(
            label: label,
            address: item.address?.shortAddress ?? item.name ?? String(localized: "Chosen place"),
            coordinate: item.location.coordinate
        )
        if label.isEmpty, let name = item.name {
            label = name
        }
        results = []
        query = ""
    }

    private func useCurrentLocation() async {
        guard let location = CLLocationManager().location else {
            errorMessage = String(localized: "Your location isn't available. Check that location access is on.")
            return
        }
        errorMessage = nil
        let item = try? await MKReverseGeocodingRequest(location: location)?.mapItems.first
        chosen = SavedPlace(
            label: label,
            address: item?.address?.shortAddress ?? String(localized: "My location"),
            coordinate: location.coordinate
        )
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = [.address, .pointOfInterest]
        let center = CLLocationManager().location?.coordinate ?? CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649)
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 40_000, longitudinalMeters: 40_000)
        do {
            results = Array(try await MKLocalSearch(request: request).start().mapItems.prefix(8))
            errorMessage = nil
        } catch {
            results = []
            errorMessage = String(localized: "Couldn't search for places. Check your connection and try again.")
        }
    }
}

#Preview {
    PlacePickerSheet(purpose: .temporaryHome) { _, _ in }
}
