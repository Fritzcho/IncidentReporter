import SwiftUI
import MapKit

/// A search result row for a route destination: place name, address and distance from the user.
struct DestinationSearchRow: View {
    let name: String
    var address: String?
    let coordinate: CLLocationCoordinate2D
    let userLocation: CLLocation?

    private var distanceText: String? {
        guard let userLocation else { return nil }
        let distance = userLocation.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        if distance < 1000 {
            return String(localized: "\(Int(distance)) m")
        }
        return String(localized: "\(distance / 1000, specifier: "%.1f") km")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let address, !address.isEmpty, address != name {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let distanceText {
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
        DestinationSearchRow(name: "Medborgarplatsen", address: "Södermalm, Stockholm",
                             coordinate: .init(latitude: 59.3142, longitude: 18.0735), userLocation: user)
        DestinationSearchRow(name: "Odenplan", coordinate: .init(latitude: 59.3429, longitude: 18.0496), userLocation: nil)
    }
}
