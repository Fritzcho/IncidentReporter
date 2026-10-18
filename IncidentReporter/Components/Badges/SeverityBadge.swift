import SwiftUI

/// A badge tag representing an incident's threat level / severity.
struct SeverityBadge: View {
    enum Size {
        case compact
        case regular

        var font: Font {
            switch self {
            case .compact:
                return .caption2.bold()
            case .regular:
                return .caption.bold()
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .compact:
                return 6
            case .regular:
                return 10
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .compact:
                return 2
            case .regular:
                return 5
            }
        }

        var backgroundOpacity: Double {
            switch self {
            case .compact:
                return 0.2
            case .regular:
                return 0.15
            }
        }
    }

    let severity: IncidentSeverity
    var size: Size = .compact

    var body: some View {
        Text(LocalizedStringKey(severity.rawValue))
            .font(size.font)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(severity.color.opacity(size.backgroundOpacity))
            .foregroundStyle(severity.color)
            .clipShape(Capsule())
    }
}

#Preview {
    HStack {
        SeverityBadge(severity: .low, size: .compact)
        SeverityBadge(severity: .medium, size: .regular)
        SeverityBadge(severity: .high, size: .regular)
    }
    .padding()
}
