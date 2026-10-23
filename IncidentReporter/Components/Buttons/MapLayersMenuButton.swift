import SwiftUI

/// A circular map control that gathers everything the map can show (police reports, safe havens,
/// each transit type, incident time range) into one menu.
struct MapLayersMenuButton: View {
    @Binding var showPoliceReports: Bool
    @Binding var showSafeHavens: Bool
    @Binding var visibleTransitModes: Set<TransitMode>
    @Binding var timeFilter: IncidentTimeFilter
    var isSyncingPolice: Bool = false
    var isLoadingTransit: Bool = false
    let onSyncPolice: () -> Void

    private var isBusy: Bool { isSyncingPolice || isLoadingTransit }

    private func binding(for mode: TransitMode) -> Binding<Bool> {
        Binding(
            get: { visibleTransitModes.contains(mode) },
            set: { isOn in
                if isOn {
                    visibleTransitModes.insert(mode)
                } else {
                    visibleTransitModes.remove(mode)
                }
            }
        )
    }

    var body: some View {
        Menu {
            Section("Show on map") {
                Toggle(isOn: $showPoliceReports) {
                    Label("Police reports", systemImage: "shield.fill")
                }
                Toggle(isOn: $showSafeHavens) {
                    Label("Safe havens", systemImage: "checkmark.shield.fill")
                }
            }

            Section("Transit stops") {
                ForEach(TransitMode.allCases) { mode in
                    Toggle(isOn: binding(for: mode)) {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                    // Keep the menu open so several types can be switched in one go
                    .menuActionDismissBehavior(.disabled)
                }
            }

            Picker(selection: $timeFilter) {
                ForEach(IncidentTimeFilter.allCases.reversed()) { filter in
                    Text(filter.displayName).tag(filter)
                }
            } label: {
                Label("Incident recency", systemImage: "clock.arrow.circlepath")
            }
            .pickerStyle(.menu)

            if showPoliceReports {
                Section {
                    Button(action: onSyncPolice) {
                        Label(isSyncingPolice ? "Syncing police events…" : "Sync police events",
                              systemImage: "arrow.clockwise")
                    }
                    .disabled(isSyncingPolice)
                }
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "square.3.layers.3d")
                    .font(.title3)
                    .foregroundStyle(Color.blue)
                    .opacity(isBusy ? 0.3 : 1)
                    .overlay {
                        if isBusy {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                // Keep the active time range visible without opening the menu
                Text(timeFilter.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(timeFilter == .week ? Color.secondary : Color.orange)
                    .clipShape(Capsule())
                    .offset(x: 6, y: 6)
            }
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel("Map layers")
        .accessibilityValue(Text("Incidents from the last \(timeFilter.displayName)"))
    }
}

#Preview {
    VStack(spacing: 16) {
        MapLayersMenuButton(
            showPoliceReports: .constant(true),
            showSafeHavens: .constant(true),
            visibleTransitModes: .constant([.metro, .train, .bus]),
            timeFilter: .constant(.twelveHours)
        ) {}
        MapLayersMenuButton(
            showPoliceReports: .constant(true),
            showSafeHavens: .constant(false),
            visibleTransitModes: .constant([.bus]),
            timeFilter: .constant(.week),
            isSyncingPolice: true
        ) {}
    }
    .padding()
}
