import SwiftUI
import SwiftData

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case swedish = "sv"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .swedish:
            return "Svenska"
        }
    }

    var flag: String {
        switch self {
        case .english:
            return "🇬🇧"
        case .swedish:
            return "🇸🇪"
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @AppStorage("incidentTimeFilter") private var timeFilter: IncidentTimeFilter = .twelveHours

    @Query private var incidents: [Incident]
    @State private var showingClearConfirmation = false
    @State private var clearedCount = 0
    @State private var showingClearedToast = false

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text("Language"),
                    footer: Text("Choose your preferred language for the interface.")
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        LanguageSelectionRow(
                            language: language,
                            isSelected: appLanguage == language.rawValue
                        ) {
                            appLanguage = language.rawValue
                        }
                    }
                }

                Section(
                    header: Text("Map Alerts & Freshness"),
                    footer: Text("Older incidents fade automatically to keep danger signals prominent.")
                ) {
                    Picker("Default Time Window", selection: $timeFilter) {
                        ForEach(IncidentTimeFilter.allCases) { filter in
                            Text(filter.displayName).tag(filter)
                        }
                    }

                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Expired Alerts (> 48h)")
                        }
                    }
                }

                Section(header: Text("Appearance & Info")) {
                    HStack {
                        Text("Active Stored Incidents")
                        Spacer()
                        Text("\(incidents.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Purge Expired Incidents?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    purgeExpiredIncidents()
                }
            } message: {
                Text("This will remove all reports older than 48 hours from your local storage.")
            }
        }
        .environment(\.locale, Locale(identifier: appLanguage))
    }

    private func purgeExpiredIncidents() {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -48, to: Date()) ?? Date()
        var count = 0
        for incident in incidents where incident.timestamp < cutoff {
            modelContext.delete(incident)
            count += 1
        }
        try? modelContext.save()
        clearedCount = count
    }
}
