import SwiftUI

/// Summary of the active safe route: walking time and distance (or the public transport trip with its
/// lines and changes), and which dangers it avoids or still passes. Tapping it opens the full steps.
struct SafeRouteSummaryCard: View {
    let destinationName: String
    /// Shown when the route doesn't start at the user's own position
    var originName: String?
    var travelTime: TimeInterval?
    var distance: Double?
    var extraTime: TimeInterval = 0
    var avoidedCount: Int = 0
    var passedCount: Int = 0
    /// Names of the dangers the route passes, or else the ones it avoids
    var dangerNames: [String] = []
    /// Set when travelling by public transport; replaces the walking summary
    var trip: TransitTrip?
    var isLoading: Bool = false
    var errorMessage: String?
    /// Opens the full route with stops and changes; nil hides the hint
    var onOpenDetails: (() -> Void)?
    let onEnd: () -> Void

    private var minutes: Int { Int(((travelTime ?? 0) / 60).rounded(.up)) }
    private var extraMinutes: Int { Int((extraTime / 60).rounded()) }

    private var distanceText: String {
        guard let distance else { return "" }
        if distance < 1000 {
            return String(localized: "\(Int(distance)) m")
        }
        return String(localized: "\(distance / 1000, specifier: "%.1f") km")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safe route to")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(destinationName)
                        .font(.headline)
                        .lineLimit(1)
                    if let originName {
                        Text("from \(originName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Button(action: onEnd) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("End route")
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Finding the fastest safe way…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if let trip {
                tripSummary(trip)
                status
            } else if travelTime != nil {
                Text("\(minutes) min walk · \(distanceText)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                status
                if !dangerNames.isEmpty {
                    Text(dangerNames.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            if onOpenDetails != nil && !isLoading && errorMessage == nil {
                Label(trip == nil ? "Directions & public transport" : "Stops & changes", systemImage: "list.bullet")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenDetails?()
        }
        .accessibilityAddTraits(onOpenDetails == nil ? [] : .isButton)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
    }

    private func tripSummary(_ trip: TransitTrip) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let departure = trip.departure, let arrival = trip.arrival {
                HStack(spacing: 4) {
                    Text("\(departure, style: .time) – \(arrival, style: .time)")
                        .monospacedDigit()
                    Text("· \(Int((arrival.timeIntervalSince(departure) / 60).rounded())) min")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 4) {
                ForEach(Array(trip.rides.enumerated()), id: \.offset) { index, ride in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    TransitLineBadge(mode: ride.mode, line: ride.line)
                }
            }
            if let first = trip.rides.first, let time = first.from.time {
                Text("From \(first.from.name) at \(time, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if passedCount > 0 {
            Label("Passes \(passedCount) reported danger(s), no faster safe way found", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if avoidedCount > 0 {
            Label(extraMinutes > 0
                  ? "Avoids \(avoidedCount) danger(s) · \(extraMinutes) min longer than fastest"
                  : "Avoids \(avoidedCount) danger(s) at no extra time",
                  systemImage: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            Label("No reported dangers on the way", systemImage: "checkmark.shield.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SafeRouteSummaryCard(destinationName: "Stockholms södra", travelTime: 1260, distance: 1650,
                             extraTime: 180, avoidedCount: 2,
                             dangerNames: ["Polisinsats vid T-Centralen", "Skadegörelse (Stockholm)"]) {}
        SafeRouteSummaryCard(destinationName: "Hem", originName: "Odenplan", travelTime: 600, distance: 820, passedCount: 1) {}
        SafeRouteSummaryCard(destinationName: "Medborgarplatsen", travelTime: 420, distance: 560, onOpenDetails: {}) {}
        SafeRouteSummaryCard(destinationName: "Sundbyberg", trip: .preview, onOpenDetails: {}) {}
        SafeRouteSummaryCard(destinationName: "Odenplan", isLoading: true) {}
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
