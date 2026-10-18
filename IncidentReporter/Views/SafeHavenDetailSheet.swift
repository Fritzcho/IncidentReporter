import SwiftUI
import CoreLocation
import MapKit

struct SafeHavenDetailSheet: View {
    let haven: SafeHaven
    let userLocation: CLLocation?
    @Environment(\.dismiss) private var dismiss

    private var distanceText: String {
        guard let userLocation else { return "Unknown distance" }
        let havenLoc = CLLocation(latitude: haven.coordinate.latitude, longitude: haven.coordinate.longitude)
        let distance = userLocation.distance(from: havenLoc)
        if distance < 1000 {
            let walkingMinutes = max(1, Int(distance / 80)) // ~80m per minute walk speed
            return "\(Int(distance)) m away • ~\(walkingMinutes) min walk"
        } else {
            return String(format: "%.1f km away", distance / 1000)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header Card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(haven.category.color.opacity(0.15))
                            .frame(width: 72, height: 72)

                        Image(systemName: haven.category.systemImage)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(haven.category.color)
                    }

                    VStack(spacing: 4) {
                        Text(haven.name)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text(haven.category.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                        Text(distanceText)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.top, 10)

                // Info Rows
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Address")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(haven.address)
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: haven.isOpen24Hours ? "clock.badge.checkmark" : "clock")
                            .font(.headline)
                            .foregroundStyle(haven.isOpen24Hours ? .green : .orange)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(haven.isOpen24Hours ? "Open 24/7 • Staffed" : "Evening hours")
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.headline)
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Safety Advice")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(haven.note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                Spacer()

                // Walking Directions button
                Button {
                    openInAppleMaps()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Walk Here (Apple Maps)")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Trygg plats • Safe Haven")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func openInAppleMaps() {
        let placemark = MKPlacemark(coordinate: haven.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = haven.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
