import SwiftUI

/// Full details of the active safe route: switch between walking and public transport, pick a trip,
/// and see every step: where to get on, platforms, departures, stops, changes and where to get off.
struct RouteDetailSheet: View {
    let plan: SafeRoutePlan
    @Binding var mode: RouteMode
    @Binding var selectedTripID: String?
    @Environment(\.dismiss) private var dismiss

    private var selectedTrip: ScoredTransitTrip? {
        plan.transitTrips.first { $0.id == selectedTripID } ?? plan.transitTrips.first
    }

    var body: some View {
        NavigationStack {
            List {
                if !plan.transitTrips.isEmpty {
                    Section {
                        Picker("Travel by", selection: $mode) {
                            ForEach(RouteMode.allCases) { mode in
                                Label { Text(mode.title) } icon: { Image(systemName: mode.systemImage) }
                                    .tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                }

                switch mode {
                case .walk:
                    walkSections
                case .transit:
                    transitSections
                }
            }
            .navigationTitle(plan.destinationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Walking

    @ViewBuilder
    private var walkSections: some View {
        let route = plan.recommended
        Section {
            Label("\(Int((route.travelTime / 60).rounded(.up))) min walk", systemImage: "figure.walk")
                .font(.headline)
            if route.dangersPassed.isEmpty {
                Label(plan.avoidedDangers.isEmpty ? "No reported dangers on the way" : "Avoids \(plan.avoidedDangers.count) danger(s)",
                      systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(route.dangersPassed) { danger in
                    Label(danger.title, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }

        Section("Directions") {
            if route.steps.isEmpty {
                Text("Follow the green line on the map.")
                    .foregroundStyle(.secondary)
            }
            ForEach(route.steps) { step in
                HStack {
                    Text(step.instruction)
                    Spacer()
                    Text(Measurement(value: step.distance, unit: UnitLength.meters),
                         format: .measurement(width: .abbreviated, usage: .road))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.subheadline)
            }
        }
    }

    // MARK: - Public transport

    @ViewBuilder
    private var transitSections: some View {
        Section("Options") {
            ForEach(plan.transitTrips) { option in
                Button {
                    withAnimation { selectedTripID = option.id }
                } label: {
                    TransitTripOptionRow(
                        trip: option.trip,
                        dangerCount: option.dangersPassed.count,
                        isSelected: option.id == selectedTrip?.id,
                        isRecommended: option.id == plan.transitTrips.first?.id
                    )
                }
                .buttonStyle(.plain)
            }
        }

        if let selectedTrip {
            Section("Steps") {
                ForEach(Array(selectedTrip.trip.legs.enumerated()), id: \.element.id) { index, leg in
                    TripLegRow(
                        leg: leg,
                        isChange: !leg.isWalk && selectedTrip.trip.rides.first?.id != leg.id,
                        dangerNames: dangerNames(for: leg, in: selectedTrip)
                    )
                    .listRowSeparator(.hidden)
                }

                if let arrival = selectedTrip.trip.arrival {
                    Label {
                        Text("Arrive \(arrival, style: .time) at \(plan.destinationName)")
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(.green)
                    }
                    .font(.subheadline)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }

    /// Dangers to flag on a step: near a walk, or at the stop where a ride is boarded or left
    private func dangerNames(for leg: TripLeg, in trip: ScoredTransitTrip) -> [String] {
        trip.dangersPassed.filter { danger in
            if leg.isWalk {
                return SafeRouteService.distance(from: danger.coordinate, to: leg.polyline) <= danger.radius
            }
            return [leg.from.coordinate, leg.to.coordinate].contains { stop in
                CLLocation(latitude: stop.latitude, longitude: stop.longitude)
                    .distance(from: CLLocation(latitude: danger.coordinate.latitude, longitude: danger.coordinate.longitude))
                    <= danger.radius + 50
            }
        }
        .map(\.title)
    }
}
