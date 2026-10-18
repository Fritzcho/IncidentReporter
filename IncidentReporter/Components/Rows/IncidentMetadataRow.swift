import SwiftUI

/// A reusable row for displaying a labeled metadata property with an icon.
struct IncidentMetadataRow<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    @ViewBuilder let content: () -> Content

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
    }
}

extension IncidentMetadataRow where Content == Text {
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        value: LocalizedStringKey,
        color: Color = .primary
    ) {
        self.init(title, systemImage: systemImage) {
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        IncidentMetadataRow("Report Source", systemImage: "shield.fill", value: "Polisen (Officiell)", color: .blue)
        IncidentMetadataRow("Time Reported", systemImage: "clock") {
            Text("10m ago")
        }
    }
    .padding()
}
