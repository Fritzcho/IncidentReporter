import SwiftUI

/// A tappable row for one taxi company or ride-hailing app.
struct TaxiProviderRow: View {
    let provider: TaxiProvider
    let onContact: () -> Void

    private var subtitle: LocalizedStringKey {
        switch provider.contact {
        case .phone(let display, _): return "Call \(display)"
        case .app: return "Open app"
        }
    }

    var body: some View {
        Button(action: onContact) {
            HStack(spacing: 12) {
                Image(systemName: "car.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(provider.color.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: provider.systemImage)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.green.gradient, in: Circle())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(subtitle)
    }
}

#Preview {
    List {
        ForEach(TaxiProvider.stockholm) { provider in
            TaxiProviderRow(provider: provider) {}
        }
    }
}
