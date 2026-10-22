import SwiftUI
import CoreLocation
import MapKit

/// Sheet showing whether each transit mode is still running at a stop and its next departures.
struct TransitStopDetailSheet: View {
    let userLocation: CLLocation?
    @State private var stop: TransitStop
    @State private var isRefreshing = false
    @State private var isPresentingTaxiLauncher = false
    @Environment(\.dismiss) private var dismiss

    /// Number of upcoming departures listed per mode.
    private let departureLimit = 6

    init(stop: TransitStop, userLocation: CLLocation?) {
        _stop = State(initialValue: stop)
        self.userLocation = userLocation
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                List {
                    Section {
                        header
                    }
                    .listRowBackground(Color.clear)

                    ForEach(stop.modes) { mode in
                        modeSection(mode, now: context.date)
                    }

                    if stop.modes.isEmpty {
                        Section {
                            summaryRow(
                                systemImage: "clock.badge.xmark",
                                color: .secondary,
                                title: "No departures right now",
                                detail: "SL has no upcoming departures listed for this stop."
                            )
                        }
                    }

                    Section {
                        Button {
                            openWalkingDirections()
                        } label: {
                            Label("Walking directions", systemImage: "figure.walk")
                        }
                        Button {
                            isPresentingTaxiLauncher = true
                        } label: {
                            Label("Call a taxi instead", systemImage: "car.fill")
                        }
                    } footer: {
                        Text("Live departures from SL. Updated \(stop.fetchedAt.formatted(date: .omitted, time: .shortened)).")
                    }
                }
            }
            .navigationTitle(stop.name)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await refresh() }
            .sheet(isPresented: $isPresentingTaxiLauncher) {
                TaxiLauncherSheet(userLocation: userLocation)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                // Keep departures live while the sheet is open
                while !Task.isCancelled {
                    await refresh()
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(stop.modes) { mode in
                    Image(systemName: mode.systemImage)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(mode.color.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(Text(mode.title))
                }
            }

            Text(stop.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            if let distance = stop.distance(from: userLocation) {
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                    Text(distanceText(distance))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func modeSection(_ mode: TransitMode, now: Date) -> some View {
        let status = stop.status(for: mode, now: now)
        let upcoming = stop.departures(for: mode)
            .filter { $0.expected >= now.addingTimeInterval(-30) }
            .prefix(departureLimit)

        Section {
            statusSummary(status, now: now)

            ForEach(Array(upcoming)) { departure in
                TransitDepartureRow(departure: departure, now: now)
            }
        } header: {
            HStack {
                Label(mode.title, systemImage: mode.systemImage)
                Spacer()
                TransitStatusBadge(status: status)
            }
        }
    }

    @ViewBuilder
    private func statusSummary(_ status: TransitServiceStatus, now: Date) -> some View {
        switch status {
        case .running(let next, let last):
            summaryRow(
                systemImage: "clock.fill",
                color: .green,
                title: "Next departure \(next.countdownText(now: now))",
                detail: "\(next.line) → \(next.destination)"
            )
            if let last {
                summaryRow(
                    systemImage: "moon.fill",
                    color: .indigo,
                    title: "Last departure \(last.expected.formatted(date: .omitted, time: .shortened))",
                    detail: "\(last.line) → \(last.destination)"
                )
            }
        case .closed(let next):
            summaryRow(
                systemImage: "moon.zzz.fill",
                color: .orange,
                title: "Closed until \(next.expected.formatted(date: .omitted, time: .shortened))",
                detail: "First departure: \(next.line) → \(next.destination)"
            )
        case .noService:
            summaryRow(
                systemImage: "xmark.circle.fill",
                color: .secondary,
                title: "No upcoming departures found",
                detail: nil
            )
        }
    }

    private func summaryRow(systemImage: String, color: Color, title: LocalizedStringKey, detail: LocalizedStringKey?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        if let updated = try? await SLTransitService.shared.refresh(stop) {
            stop = updated
        }
    }

    private func openWalkingDirections() {
        let location = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = stop.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func distanceText(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            let walkingMinutes = max(1, Int(distance / 80)) // ~80m per minute walk speed
            return String(localized: "\(Int(distance)) m away • ~\(walkingMinutes) min walk")
        }
        return String(localized: "\(distance / 1000, specifier: "%.1f") km away")
    }
}

#Preview {
    TransitStopDetailSheet(
        stop: TransitStop(
            id: 9001,
            name: "T-Centralen",
            coordinate: .init(latitude: 59.3314, longitude: 18.0604),
            modes: [.metro, .train, .bus],
            departures: [
                TransitDeparture(
                    id: "1", mode: .metro, line: "11", destination: "Akalla",
                    scheduled: .now.addingTimeInterval(120), expected: .now.addingTimeInterval(120), platform: "6"
                ),
                TransitDeparture(
                    id: "2", mode: .metro, line: "11", destination: "Akalla",
                    scheduled: .now.addingTimeInterval(9000), expected: .now.addingTimeInterval(9000), platform: "6"
                ),
                TransitDeparture(
                    id: "4", mode: .train, line: "41", destination: "Märsta",
                    scheduled: .now.addingTimeInterval(600), expected: .now.addingTimeInterval(600), platform: "1"
                ),
                TransitDeparture(
                    id: "3", mode: .bus, line: "69", destination: "Blockhusudden",
                    scheduled: .now.addingTimeInterval(300), expected: .now.addingTimeInterval(420), platform: "C"
                )
            ],
            fetchedAt: .now
        ),
        userLocation: CLLocation(latitude: 59.3326, longitude: 18.0649)
    )
}
