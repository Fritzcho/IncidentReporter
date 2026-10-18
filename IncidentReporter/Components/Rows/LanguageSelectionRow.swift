import SwiftUI

/// A selectable row representing an interface language option.
struct LanguageSelectionRow: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(language.flag)
                    .font(.title3)
                Text(language.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.bold())
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
    }
}
