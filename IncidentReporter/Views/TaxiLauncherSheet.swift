import SwiftUI
import CoreLocation
import MapKit

/// Sheet for calling a Stockholm taxi or opening a ride-hailing app, with the pickup address to read out.
struct TaxiLauncherSheet: View {
    let userLocation: CLLocation?
    @State private var pickupAddress: String?
    @State private var failedProvider: TaxiProvider?
    @State private var didCopyAddress = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrentLocationDisplayView(
                        coordinate: userLocation?.coordinate,
                        addressSummary: pickupAddress
                    )

                    if let pickupAddress {
                        Button {
                            UIPasteboard.general.string = pickupAddress
                            didCopyAddress = true
                        } label: {
                            Label(didCopyAddress ? "Address copied" : "Copy pickup address",
                                  systemImage: didCopyAddress ? "checkmark" : "doc.on.doc")
                        }
                    }
                } header: {
                    Text("Pickup location")
                } footer: {
                    Text("Tell the dispatcher this address when you call.")
                }

                Section("Taxi companies") {
                    ForEach(TaxiProvider.stockholm.filter { if case .phone = $0.contact { true } else { false } }) { provider in
                        TaxiProviderRow(provider: provider) { contact(provider) }
                    }
                }

                Section {
                    ForEach(TaxiProvider.stockholm.filter { if case .app = $0.contact { true } else { false } }) { provider in
                        TaxiProviderRow(provider: provider) { contact(provider) }
                    }
                } header: {
                    Text("Ride apps")
                } footer: {
                    Text("In an emergency, call 112.")
                }
            }
            .navigationTitle("Call a Taxi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Couldn't open \(failedProvider?.name ?? "")",
                isPresented: Binding(get: { failedProvider != nil }, set: { if !$0 { failedProvider = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This device can't place phone calls.")
            }
            .task(id: userLocation.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" }) {
                await reverseGeocodePickup()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func contact(_ provider: TaxiProvider) {
        openURL(provider.primaryURL) { accepted in
            guard !accepted else { return }
            if let fallback = provider.fallbackURL {
                openURL(fallback)
            } else {
                failedProvider = provider
            }
        }
    }

    private func reverseGeocodePickup() async {
        guard let userLocation,
              let request = MKReverseGeocodingRequest(location: userLocation),
              let item = try? await request.mapItems.first else {
            return
        }
        // Street address when Apple has one, otherwise the nearest landmark + postcode
        pickupAddress = item.address?.shortAddress ?? item.name
    }
}

#Preview {
    TaxiLauncherSheet(userLocation: CLLocation(latitude: 59.3428, longitude: 18.0496))
}
