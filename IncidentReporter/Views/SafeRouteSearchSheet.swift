import SwiftUI
import MapKit

/// Pick where a safe walking route starts and ends. The start is the user's own position unless they
/// type another place; picking both starts the route.
struct SafeRouteSearchSheet: View {
    private enum Field {
        case origin
        case destination
    }

    let userLocation: CLLocation?
    /// Where "home" currently is (the temporary home while one is active), offered as a shortcut
    var home: SavedPlace?
    var isTemporaryHome = false
    /// The user's other saved places, offered as shortcuts
    var savedPlaces: [SavedPlace] = []
    /// nil origin means "my location"
    let onSelect: (_ origin: MKMapItem?, _ destination: MKMapItem) -> Void

    @State private var originText: String
    @State private var destinationText: String
    @State private var origin: MKMapItem?
    @State private var destination: MKMapItem?
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @FocusState private var isOriginFocused: Bool
    @FocusState private var isDestinationFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        userLocation: CLLocation?,
        origin: MKMapItem? = nil,
        destination: MKMapItem? = nil,
        home: SavedPlace? = nil,
        isTemporaryHome: Bool = false,
        savedPlaces: [SavedPlace] = [],
        onSelect: @escaping (_ origin: MKMapItem?, _ destination: MKMapItem) -> Void
    ) {
        self.userLocation = userLocation
        self.home = home
        self.isTemporaryHome = isTemporaryHome
        self.savedPlaces = savedPlaces
        self.onSelect = onSelect
        _origin = State(initialValue: origin)
        _destination = State(initialValue: destination)
        _originText = State(initialValue: origin?.name ?? "")
        _destinationText = State(initialValue: destination?.name ?? "")
    }

    private var activeField: Field {
        isOriginFocused ? .origin : .destination
    }

    private var query: String {
        (activeField == .origin ? originText : destinationText).trimmingCharacters(in: .whitespaces)
    }

    /// Saved places are offered for either end until the user starts typing
    private var showsShortcuts: Bool {
        query.isEmpty && (home != nil || !savedPlaces.isEmpty)
    }

    /// The start field shows "My location" until the user types another place
    private var isOriginMyLocation: Bool {
        origin == nil && originText.isEmpty
    }

    /// Typed text that hasn't been matched to a place from the list yet
    private var hasUnresolvedOrigin: Bool {
        !originText.isEmpty && originText != origin?.name
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    RouteEndpointField(
                        kind: .origin,
                        text: $originText,
                        isMyLocation: isOriginMyLocation,
                        focus: $isOriginFocused
                    ) {
                        useMyLocation()
                    }
                    RouteEndpointField(
                        kind: .destination,
                        text: $destinationText,
                        focus: $isDestinationFocused
                    ) {
                        destination = nil
                        destinationText = ""
                        isDestinationFocused = true
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)

                List {
                    if showsShortcuts {
                        Section("My places") {
                            if let home {
                                Button {
                                    choose(home.mapItem)
                                } label: {
                                    SavedPlaceRow(
                                        systemImage: isTemporaryHome ? "moon.zzz.fill" : "house.fill",
                                        tint: isTemporaryHome ? .indigo : .blue,
                                        title: home.label,
                                        address: home.address,
                                        detail: isTemporaryHome ? Text("Temporary home") : nil
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(savedPlaces) { place in
                                Button {
                                    choose(place.mapItem)
                                } label: {
                                    SavedPlaceRow(systemImage: "mappin", tint: .orange, title: place.label, address: place.address)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if activeField == .origin {
                        Button {
                            useMyLocation()
                        } label: {
                            Label("My location", systemImage: "location.fill")
                                .foregroundStyle(.blue)
                        }
                    }

                    Section {
                        ForEach(results, id: \.self) { item in
                            Button {
                                choose(item)
                            } label: {
                                DestinationSearchRow(
                                    name: item.name ?? String(localized: "Place"),
                                    address: item.address?.shortAddress,
                                    coordinate: item.location.coordinate,
                                    userLocation: userLocation
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } footer: {
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if isSearching && results.isEmpty {
                        ProgressView()
                    } else if query.isEmpty && activeField == .destination && !showsShortcuts {
                        ContentUnavailableView(
                            "Where are you going?",
                            systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                            description: Text("Get the fastest walking route there that avoids recent reported dangers.")
                        )
                    } else if !isSearching && results.isEmpty && !query.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
            .navigationTitle("Safe route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task(id: "\(activeField)-\(query)") {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await search()
            }
            .task {
                // Most routes start where the user is, so start by asking where they're going
                try? await Task.sleep(for: .milliseconds(400))
                if destination == nil {
                    isDestinationFocused = true
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func useMyLocation() {
        origin = nil
        originText = ""
        errorMessage = nil
        isDestinationFocused = destination == nil
        if destination != nil {
            isOriginFocused = false
            finishIfReady()
        }
    }

    private func choose(_ item: MKMapItem) {
        let name = item.name ?? String(localized: "Place")
        if activeField == .origin {
            origin = item
            originText = name
        } else {
            destination = item
            destinationText = name
        }
        errorMessage = nil
        finishIfReady()
    }

    /// Starts the route once both ends are chosen; otherwise moves to the field still missing.
    private func finishIfReady() {
        guard !hasUnresolvedOrigin else {
            errorMessage = String(localized: "Pick a start point from the list, or choose My location.")
            isOriginFocused = true
            return
        }
        guard let destination else {
            isDestinationFocused = true
            return
        }
        onSelect(origin, destination)
        dismiss()
    }

    private func search() async {
        guard !query.isEmpty else {
            results = []
            return
        }
        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        let center = userLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649)
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 20_000, longitudinalMeters: 20_000)
        do {
            results = try await MKLocalSearch(request: request).start().mapItems
            errorMessage = nil
        } catch {
            results = []
            errorMessage = String(localized: "Couldn't search for places. Check your connection and try again.")
        }
    }
}

#Preview {
    SafeRouteSearchSheet(userLocation: CLLocation(latitude: 59.3326, longitude: 18.0649)) { _, _ in }
}
