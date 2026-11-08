import SwiftUI

/// A circular map control button that presents a menu to filter incidents by age/decay.
struct TimeFilterMenuButton: View {
    @Binding var timeFilter: IncidentTimeFilter

    var body: some View {
        Menu {
            Section("Incident Recency") {
                ForEach(IncidentTimeFilter.allCases.reversed()) { filter in
                    Button {
                        timeFilter = filter
                    } label: {
                        if timeFilter == filter {
                            Label(filter.displayName, systemImage: "checkmark")
                        } else {
                            Text(filter.displayName)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(timeFilter == .week ? Color.secondary : Color.orange)
                .overlay(alignment: .bottomTrailing) {
                    Text(timeFilter.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(timeFilter == .week ? Color.secondary : Color.orange)
                        .clipShape(Capsule())
                        .offset(x: 4, y: 4)
                }
        }
        .buttonStyle(.circularMapControl)
        .accessibilityLabel("Filter by time range: \(timeFilter.displayName)")
    }
}

#Preview {
    VStack {
        TimeFilterMenuButton(timeFilter: .constant(.twelveHours))
        TimeFilterMenuButton(timeFilter: .constant(.week))
    }
    .padding()
}
