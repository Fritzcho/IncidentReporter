import SwiftUI
import CoreLocation

/// A search result row for an SL stop: name, disambiguating area and distance from the user.
struct TransitStopSearchRow: View {
    let stop: TransitStopSummary
    let userLocation: CLLocation?
    var isLoading: Bool = false

    private var distanceText: String? {
        guard let distance = stop.distance(from: userLocation) else { return nil }
        if distance < 1000 {
            return String(localized: "\(Int(distance)) m")
        }
        return String(localized: "\(distance / 1000, specifier: "%.1f") km")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(stop.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let note = stop.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
            } else if let distanceText {
                Text(distanceText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let user = CLLocation(latitude: 59.3326, longitude: 18.0649)
    List {
        TransitStopSearchRow(
            stop: TransitStopSummary(id: 9530, name: "Stockholms södra", note: nil,
                                     coordinate: .init(latitude: 59.3134, longitude: 18.0614)),
            userLocation: user
        )
        TransitStopSearchRow(
            stop: TransitStopSummary(id: 102, name: "Styrsvik", note: "Runmarö",
                                     coordinate: .init(latitude: 59.2803, longitude: 18.7314)),
            userLocation: user
        )
        TransitStopSearchRow(
            stop: TransitStopSummary(id: 9001, name: "T-Centralen", note: nil,
                                     coordinate: .init(latitude: 59.3314, longitude: 18.0604)),
            userLocation: user,
            isLoading: true
        )
    }
}
