import SwiftUI

/// A circular map control button that toggles visibility of Safe Havens (Trygga platser).
struct SafeHavensFilterButton: View {
    @Binding var showSafeHavens: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showSafeHavens.toggle()
            }
        } label: {
            Image(systemName: showSafeHavens ? "checkmark.shield.fill" : "checkmark.shield")
                .font(.title3)
                .foregroundStyle(showSafeHavens ? Color.green : Color.secondary)
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel(showSafeHavens ? "Hide safe havens" : "Show safe havens")
    }
}

#Preview {
    VStack {
        SafeHavensFilterButton(showSafeHavens: .constant(true))
        SafeHavensFilterButton(showSafeHavens: .constant(false))
    }
    .padding()
}
