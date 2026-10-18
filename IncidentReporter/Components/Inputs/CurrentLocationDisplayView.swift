import SwiftUI
import CoreLocation

/// Displays the current GPS location coordinates and geocoded summary, or a fallback warning.
struct CurrentLocationDisplayView: View {
    let coordinate: CLLocationCoordinate2D?
    let addressSummary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coordinate {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color.accentColor)
                    if let summary = addressSummary {
                        Text(summary)
                            .font(.subheadline)
                    } else {
                        Text("Current device GPS location")
                            .font(.subheadline)
                    }
                }

                HStack {
                    Text("Coordinates")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("GPS location not available. Defaulting to Central Stockholm.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    Form {
        CurrentLocationDisplayView(
            coordinate: CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649),
            addressSummary: "Central Station, Stockholm"
        )
        CurrentLocationDisplayView(coordinate: nil, addressSummary: nil)
    }
}
