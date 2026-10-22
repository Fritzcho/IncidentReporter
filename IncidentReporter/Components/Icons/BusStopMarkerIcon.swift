import SwiftUI

/// A small, low-emphasis map marker for an SL stop. Shown for every stop in view when zoomed in;
/// tapping it opens the stop's departures.
struct BusStopMarkerIcon: View {
    let name: String
    var isLoading: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)

            if isLoading {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Image(systemName: "bus.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 17, height: 17)
                    .background(Color.red.gradient, in: Circle())
            }
        }
        // Keep a comfortable tap target around the small glyph
        .frame(width: 34, height: 34)
        .contentShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Stop \(name)"))
        .accessibilityHint(Text("Shows departures"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack(spacing: 20) {
        BusStopMarkerIcon(name: "Fatbursgatan")
        BusStopMarkerIcon(name: "Fatbursgatan", isLoading: true)
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}
