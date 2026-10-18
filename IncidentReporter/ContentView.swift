import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appLanguage") private var appLanguage: String = "en"

    var body: some View {
        TabView {
            IncidentMapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            IncidentListView()
                .tabItem {
                    Label("Incidents", systemImage: "list.bullet.rectangle.portrait")
                }
        }
        .environment(\.locale, Locale(identifier: appLanguage))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Incident.self, inMemory: true)
}
