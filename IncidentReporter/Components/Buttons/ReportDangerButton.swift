import SwiftUI

/// A prominent call-to-action button for reporting a new safety danger or incident.
struct ReportDangerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Report Danger", systemImage: "exclamationmark.shield.fill")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.accentColor.gradient)
                .clipShape(Capsule())
                .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    ReportDangerButton {}
        .padding()
}
