import SwiftUI

/// A circular map control button that opens the SL stop search.
struct TransitSearchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.blue)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(2.5)
                        .background(Color.blue, in: Circle())
                        .offset(x: 6, y: 5)
                }
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel("Search departures at any stop")
    }
}

#Preview {
    TransitSearchButton {}
        .padding()
}
