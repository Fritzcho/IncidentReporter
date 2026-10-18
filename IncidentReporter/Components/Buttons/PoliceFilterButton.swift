import SwiftUI

/// A circular map control button that toggles the visibility of police reports.
struct PoliceFilterButton: View {
    @Binding var showPoliceReports: Bool

    var body: some View {
        Button {
            withAnimation {
                showPoliceReports.toggle()
            }
        } label: {
            Image(systemName: showPoliceReports ? "shield.fill" : "shield.slash.fill")
                .font(.title3)
                .foregroundStyle(showPoliceReports ? Color.blue : Color.secondary)
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel(showPoliceReports ? "Disable police reports" : "Enable police reports")
    }
}

#Preview {
    VStack {
        PoliceFilterButton(showPoliceReports: .constant(true))
        PoliceFilterButton(showPoliceReports: .constant(false))
    }
    .padding()
}
