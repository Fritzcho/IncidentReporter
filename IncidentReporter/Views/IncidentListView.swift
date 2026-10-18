import SwiftUI
import SwiftData
import CoreLocation

enum IncidentSourceTab: String, CaseIterable, Identifiable {
    case community = "Community"
    case police = "Police"

    var id: String { rawValue }
}

struct IncidentListView: View {
    @Query(sort: \Incident.timestamp, order: .reverse) private var incidents: [Incident]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedIncident: Incident?
    @State private var selectedTab: IncidentSourceTab = .community
    @State private var isPresentingSettings = false

    private var tabFilteredIncidents: [Incident] {
        switch selectedTab {
        case .community:
            return incidents.filter { !$0.isPoliceReport }
        case .police:
            return incidents.filter { $0.isPoliceReport }
        }
    }

    private var filteredIncidents: [Incident] {
        if searchText.isEmpty {
            return tabFilteredIncidents
        } else {
            return tabFilteredIncidents.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                $0.details.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Incident Source", selection: $selectedTab) {
                    ForEach(IncidentSourceTab.allCases) { tab in
                        Text(LocalizedStringKey(tab.rawValue)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 6)

                List {
                    if filteredIncidents.isEmpty {
                        ContentUnavailableView(
                            selectedTab == .community ? "No Community Reports" : "No Police Alerts",
                            systemImage: selectedTab == .community ? "person.3.fill" : "shield.badge.checkmark",
                            description: Text(
                                searchText.isEmpty
                                    ? (selectedTab == .community ? "No community incidents reported yet." : "No active police incidents in this area.")
                                    : "No alerts match your search."
                            )
                        )
                    } else {
                        ForEach(filteredIncidents) { incident in
                            Button {
                                selectedIncident = incident
                            } label: {
                                IncidentRowView(incident: incident)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search alerts, categories, advice...")
            .refreshable {
                let reference = CLLocation(latitude: 59.3326, longitude: 18.0649)
                await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: reference, force: true)
            }
            .navigationTitle("Safety Alerts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .onAppear {
                if selectedIncident == nil && !isPresentingSettings {
                    selectedTab = .community
                }
            }
            .sheet(item: $selectedIncident) { incident in
                IncidentDetailSheet(incident: incident, userLocation: nil)
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
            }
        }
    }
}
