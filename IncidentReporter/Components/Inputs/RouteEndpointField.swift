import SwiftUI

/// One end of a route ("From" or "To"): a text field that searches places, or shows the chosen place.
/// Shows "My location" in blue when the start point is the user's own position.
struct RouteEndpointField: View {
    enum Kind {
        case origin
        case destination

        var systemImage: String {
            switch self {
            case .origin: return "circle.circle.fill"
            case .destination: return "flag.checkered.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .origin: return .blue
            case .destination: return .green
            }
        }

        var prompt: LocalizedStringKey {
            switch self {
            case .origin: return "From: my location or a place"
            case .destination: return "To: address or place"
            }
        }
    }

    let kind: Kind
    @Binding var text: String
    /// True while the field stands for the user's own position rather than typed text
    var isMyLocation: Bool = false
    var focus: FocusState<Bool>.Binding
    let onClear: () -> Void

    private var showsMyLocation: Bool {
        isMyLocation && !focus.wrappedValue
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: kind.systemImage)
                .font(.title3)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)

            // The field is always there so a tap can focus it; "My location" is drawn over it until the user types
            // (Hiding it with opacity would stop it receiving taps, so only the placeholder is dropped)
            TextField("", text: $text, prompt: showsMyLocation ? nil : Text(kind.prompt))
                .focused(focus)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .leading) {
                    if showsMyLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                            Text("My location")
                        }
                        .foregroundStyle(.blue)
                        .allowsHitTesting(false)
                    }
                }
                .accessibilityLabel(showsMyLocation ? Text("From my location") : Text(kind.prompt))
                .accessibilityHint(showsMyLocation ? Text("Type to start from another place") : Text(""))

            if !text.isEmpty || (kind == .origin && !isMyLocation) {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind == .origin ? "Start from my location" : "Clear destination")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        // A tap anywhere on the row, not just on the text, starts typing
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            focus.wrappedValue = true
        }
    }
}

#Preview {
    @Previewable @State var from = ""
    @Previewable @State var to = "Medborgarplatsen"
    @Previewable @FocusState var fromFocused: Bool
    @Previewable @FocusState var toFocused: Bool
    VStack(spacing: 8) {
        RouteEndpointField(kind: .origin, text: $from, isMyLocation: true, focus: $fromFocused) {}
        RouteEndpointField(kind: .destination, text: $to, focus: $toFocused) {}
        RouteEndpointField(kind: .origin, text: .constant("Odenplan"), focus: $fromFocused) {}
    }
    .padding()
}
