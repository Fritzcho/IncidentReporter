import SwiftUI
import CoreLocation

/// An input field with search trigger, progress indicator, and result display for custom address lookup.
struct CustomAddressInputView: View {
    @Binding var addressInput: String
    let isGeocoding: Bool
    let errorMessage: String?
    let resolvedAddress: String?
    let resolvedCoordinate: CLLocationCoordinate2D?
    let onSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Enter street address or intersection...", text: $addressInput)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        onSearch()
                    }

                if isGeocoding {
                    ProgressView()
                        .padding(.horizontal, 4)
                } else {
                    Button("Find") {
                        onSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(addressInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if let errorMsg = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(errorMsg)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let resolved = resolvedAddress, let coord = resolvedCoordinate {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(resolved)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }

                    Text(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    Form {
        CustomAddressInputView(
            addressInput: .constant("Drottninggatan 1"),
            isGeocoding: false,
            errorMessage: nil,
            resolvedAddress: "Drottninggatan 1, Stockholm",
            resolvedCoordinate: CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649),
            onSearch: {}
        )
    }
}
