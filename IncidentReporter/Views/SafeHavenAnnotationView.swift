import SwiftUI

struct SafeHavenAnnotationView: View {
    let haven: SafeHaven
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(haven.category.color.gradient)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)
                    .shadow(color: haven.category.color.opacity(0.4), radius: 5, x: 0, y: 2)

                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .frame(width: isSelected ? 44 : 36, height: isSelected ? 44 : 36)

                Image(systemName: haven.category.systemImage)
                    .font(.system(size: isSelected ? 18 : 14, weight: .bold))
                    .foregroundStyle(.white)
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green)
                .background(Circle().fill(.white).frame(width: 8, height: 8))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
