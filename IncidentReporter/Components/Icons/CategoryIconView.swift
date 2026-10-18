import SwiftUI

/// A reusable circular icon representing an incident category.
struct CategoryIconView: View {
    enum Style {
        case tinted
        case gradient
    }

    let category: IncidentCategory
    var size: CGFloat = 44
    var style: Style = .tinted

    private var iconFont: Font {
        if size >= 56 {
            return .title2.bold()
        } else if size >= 44 {
            return .headline
        } else {
            return .subheadline
        }
    }

    var body: some View {
        ZStack {
            switch style {
            case .tinted:
                Circle()
                    .fill(category.color.opacity(0.15))
                    .frame(width: size, height: size)

                Image(systemName: category.systemImage)
                    .foregroundStyle(category.color)
                    .font(iconFont)

            case .gradient:
                Circle()
                    .fill(category.color.gradient)
                    .frame(width: size, height: size)

                Image(systemName: category.systemImage)
                    .font(iconFont)
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        CategoryIconView(category: .stalking, size: 44, style: .tinted)
        CategoryIconView(category: .drinkSpiking, size: 56, style: .gradient)
    }
    .padding()
}
