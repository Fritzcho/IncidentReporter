import SwiftUI

/// A circular map control button that toggles between satellite and standard map styles.
struct MapStyleToggleButton: View {
    @Binding var isSatelliteStyle: Bool

    var body: some View {
        Button {
            withAnimation {
                isSatelliteStyle.toggle()
            }
        } label: {
            Image(systemName: isSatelliteStyle ? "globe.americas.fill" : "map")
                .font(.title3)
                .foregroundStyle(isSatelliteStyle ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel(isSatelliteStyle ? "Switch to standard map" : "Switch to satellite map")
    }
}

#Preview {
    VStack {
        MapStyleToggleButton(isSatelliteStyle: .constant(false))
        MapStyleToggleButton(isSatelliteStyle: .constant(true))
    }
    .padding()
}
