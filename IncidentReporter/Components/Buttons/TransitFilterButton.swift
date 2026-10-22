import SwiftUI

/// A circular map control button that toggles the nearest subway, commuter train and bus stop pins.
struct TransitFilterButton: View {
    @Binding var showTransit: Bool
    var isLoading: Bool = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showTransit.toggle()
            }
        } label: {
            ZStack {
                Image(systemName: "tram.fill.tunnel")
                    .font(.title3)
                    .foregroundStyle(showTransit ? Color.blue : Color.secondary)
                    .opacity(isLoading ? 0.3 : 1)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel(showTransit ? Text("Hide nearest transit stops") : Text("Show nearest transit stops"))
    }
}

#Preview {
    VStack {
        TransitFilterButton(showTransit: .constant(true))
        TransitFilterButton(showTransit: .constant(false))
        TransitFilterButton(showTransit: .constant(true), isLoading: true)
    }
    .padding()
}
