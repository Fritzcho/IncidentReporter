import SwiftUI

/// A trusted contact in a list, marking the one the safety timer alerts.
struct TrustedContactRow: View {
    let name: String
    let phone: String
    var isPrimary: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.teal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? String(localized: "Unnamed contact") : name)
                    .font(.subheadline.weight(.semibold))
                Text(phone)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            if isPrimary {
                Text("Safety timer")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.teal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.teal.opacity(0.15), in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        TrustedContactRow(name: "Emma", phone: "+46 70 123 45 67", isPrimary: true)
        TrustedContactRow(name: "Mamma", phone: "070-765 43 21")
    }
}
