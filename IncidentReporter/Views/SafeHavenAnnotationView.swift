import SwiftUI

struct SafeHavenAnnotationView: View {
    let haven: SafeHaven
    let isSelected: Bool

    private var circleSize: CGFloat {
        isSelected ? 34 : 26
    }

    var body: some View {
        VStack(spacing: 1.5) {
            ZStack {
                Circle()
                    .fill(haven.category.color.gradient)
                    .frame(width: circleSize, height: circleSize)
                    .shadow(color: haven.category.color.opacity(0.35), radius: 3, x: 0, y: 1.5)

                Circle()
                    .strokeBorder(.white, lineWidth: 1.5)
                    .frame(width: circleSize, height: circleSize)

                Image(systemName: haven.category.systemImage)
                    .font(.system(size: isSelected ? 14 : 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: isSelected ? 9 : 7, weight: .bold))
                .foregroundStyle(.green)
                .background(Circle().fill(.white).frame(width: isSelected ? 7 : 5, height: isSelected ? 7 : 5))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
}
