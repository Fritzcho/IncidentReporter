import SwiftUI

/// A circular map control button for reporting a new safety danger or incident.
struct ReportDangerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(.white)
                        .offset(x: 6, y: -4)
                }
        }
        .buttonStyle(.circularMapControl(isFilled: true, fillColor: .red))
        .accessibilityLabel("Report danger")
    }
}

#Preview {
    HStack(spacing: 16) {
        ReportDangerButton {}
    }
    .padding()
}
