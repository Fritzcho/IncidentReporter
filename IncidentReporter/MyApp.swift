import SwiftUI
import SwiftData
import CoreLocation

@main
struct IncidentTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Incident.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // Pre-seed or refresh sample incidents for Central Stockholm
            Task { @MainActor in
                let context = container.mainContext
                let descriptor = FetchDescriptor<Incident>()
                if let existing = try? context.fetch(descriptor) {
                    let hasOutdatedData = existing.contains { $0.latitude < 50.0 }
                    if existing.isEmpty || hasOutdatedData {
                        for old in existing {
                            context.delete(old)
                        }
                        for incident in SampleIncidents.createSampleIncidents() {
                            context.insert(incident)
                        }
                        try? context.save()
                    }
                }

                // Initial fetch of Swedish Police events within 25km on launch
                let stockholmCenter = CLLocation(latitude: 59.3326, longitude: 18.0649)
                await PoliceAPIService.syncWithDatabase(
                    modelContext: context,
                    referenceLocation: stockholmCenter
                )
            }
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
