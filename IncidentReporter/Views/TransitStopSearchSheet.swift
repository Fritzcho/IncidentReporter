import SwiftUI
import CoreLocation

/// Search any SL stop by name and open its live departures. Shows the closest stops before the user types.
struct TransitStopSearchSheet: View {
    let userLocation: CLLocation?
    @State private var query = ""
    @State private var results: [TransitStopSummary] = []
    @State private var isSearching = false
    @State private var loadingStopID: Int?
    @State private var selectedStop: TransitStop?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var isShowingNearby: Bool {
        query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(results) { stop in
                        Button {
                            Task { await open(stop) }
                        } label: {
                            TransitStopSearchRow(
                                stop: stop,
                                userLocation: userLocation,
                                isLoading: loadingStopID == stop.id
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(loadingStopID != nil)
                    }
                } header: {
                    if !results.isEmpty {
                        Text(isShowingNearby ? "Nearby stops" : "Stops")
                    }
                } footer: {
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .overlay {
                if isSearching && results.isEmpty {
                    ProgressView()
                } else if !isSearching && results.isEmpty && !isShowingNearby {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Departures")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search any SL stop")
            )
            .autocorrectionDisabled()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: query) {
                // Debounce typing before searching the stop register
                if !isShowingNearby {
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                }
                await search()
            }
            .sheet(item: $selectedStop) { stop in
                TransitStopDetailSheet(stop: stop, userLocation: userLocation)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func search() async {
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await SLTransitService.shared.searchStops(matching: query, near: userLocation)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't load SL stops. Check your connection and try again.")
        }
    }

    private func open(_ summary: TransitStopSummary) async {
        loadingStopID = summary.id
        defer { loadingStopID = nil }
        do {
            selectedStop = try await SLTransitService.shared.stop(for: summary)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Couldn't load departures for \(summary.name).")
        }
    }
}

#Preview {
    TransitStopSearchSheet(userLocation: CLLocation(latitude: 59.3326, longitude: 18.0649))
}
