import SwiftUI

/// A saved place in a list: icon, the user's label, the address and an optional note such as "until 10:00".
struct SavedPlaceRow: View {
    let systemImage: String
    var tint: Color = .blue
    let title: String
    let address: String
    var detail: Text?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(tint.gradient, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let detail {
                    detail
                        .font(.caption)
                        .foregroundStyle(tint)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        SavedPlaceRow(systemImage: "house.fill", title: "Home", address: "Götgatan 67, Stockholm")
        SavedPlaceRow(systemImage: "moon.zzz.fill", tint: .indigo, title: "Anna's place", address: "Odengatan 12",
                      detail: Text("Until tomorrow 10:00"))
        SavedPlaceRow(systemImage: "mappin", tint: .orange, title: "Work", address: "Kungsgatan 8")
    }
}
