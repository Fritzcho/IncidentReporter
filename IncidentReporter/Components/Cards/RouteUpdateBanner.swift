import SwiftUI

/// Banner shown when something new happens on the active safe route: either the route was changed
/// to avoid a new danger, or no safer way exists and the user should stay alert.
struct RouteUpdateBanner: View {
    let title: String
    let message: String
    var isRerouted: Bool = true
    let onDismiss: () -> Void

    private var tint: Color { isRerouted ? .green : .orange }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isRerouted ? "arrow.triangle.branch" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .padding(.horizontal, 14)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 12) {
        RouteUpdateBanner(
            title: "Rerouted around a new danger",
            message: "Polisinsats vid Slussen. New route: 14 min."
        ) {}
        RouteUpdateBanner(
            title: "New danger on your route",
            message: "Skadegörelse (Stockholm). No safer way found, stay alert.",
            isRerouted: false
        ) {}
    }
    .background(Color.gray.opacity(0.2))
}
