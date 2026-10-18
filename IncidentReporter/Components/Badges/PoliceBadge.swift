import SwiftUI

/// A badge tag representing an official Swedish Police report.
struct PoliceBadge: View {
    enum Size {
        case compact
        case regular
        
        var font: Font {
            switch self {
            case .compact:
                return .system(size: 9, weight: .bold)
            case .regular:
                return .caption2.bold()
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .compact:
                return 5
            case .regular:
                return 6
            }
        }
    }
    
    var size: Size = .compact

    var body: some View {
        Text("POLISEN")
            .font(size.font)
            .foregroundStyle(.white)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, 2)
            .background(Color.blue)
            .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        PoliceBadge(size: .compact)
        PoliceBadge(size: .regular)
    }
    .padding()
}
