# Component Architecture & Guidelines

This directory contains reusable SwiftUI components for the **IncidentReporter** app. Reusable UI elements must be decoupled from screen-level views (`Views/`) and categorized into their corresponding subfolder.

---

## Directory Organization

Components are organized by their visual role:

| Subfolder | Purpose & Scope | Examples |
| :--- | :--- | :--- |
| **`Badges/`** | Informational tags, status pills, and severity indicators. | `PoliceBadge.swift`, `SeverityBadge.swift` |
| **`Buttons/`** | Action buttons, toggles, controls, and custom `ButtonStyle` definitions. | `MapStyleToggleButton.swift`, `ReportDangerButton.swift`, `CircularMapControlButtonStyle.swift` |
| **`Cards/`** | Standalone card containers, header summary blocks, and card surfaces. | `IncidentDetailHeaderView.swift` |
| **`Icons/`** | Categorical or decorative iconography, symbol wrappers, and avatar-style circles. | `CategoryIconView.swift` |
| **`Inputs/`** | Input fields, search controls, geocoding fields, and coordinate summary displays. | `CustomAddressInputView.swift`, `CurrentLocationDisplayView.swift` |
| **`Rows/`** | List items, table cell content, and metadata key-value rows. | `IncidentRowView.swift`, `IncidentMetadataRow.swift`, `LanguageSelectionRow.swift` |

> **Rule**: When introducing a new component, choose an existing category above. Do not create a new subfolder unless a new distinct component type is needed across multiple views (e.g. `Banners/`, `Sheets/`). Do not place `.swift` files directly in the root of `Components/`.

---

## Component Design Standards

### 1. Separation of Concerns & State
- **Stateless by default**: Prefer passing values (`let`) and callback actions (`let onSelect: () -> Void`) rather than embedding queries, network calls, or direct `modelContext` operations.
- **Two-way bindings**: Use `@Binding` for controls that mutate state owned by a parent (e.g., `@Binding var isToggled: Bool`).
- **Private state**: Use `@State private var` strictly for internal animation or visual effects (e.g., button press state, rotation state).

### 2. Localization
- Always use `LocalizedStringKey` or standard SwiftUI String catalog keys for UI text.
- Ensure strings are documented and match entries in `Localizable.xcstrings`.

### 3. Accessibility
- All icon-only buttons **must** have an `.accessibilityLabel(...)`.
- Include appropriate accessibility traits where needed.

### 4. Previews
- Every component file **must** include a `#Preview` demonstrating key variants (e.g. compact vs regular, enabled vs disabled, different severities/categories).

### 5. Formatting & Code Style
- **Indentation**: 4 spaces.
- **Documentation**: Provide a top-level DocC docstring (`/// Description`) for each component and enum.
- **Naming**: PascalCase for types (e.g. `SeverityBadge`), camelCase for properties and functions.

---

## Workflow for AI Agents

When asked to build or refactor a component:

1. **Locate Target Subfolder**: Identify whether the component is a Badge, Button, Card, Icon, Input, or Row.
2. **Create File**: Use `XcodeWrite` with path `IncidentReporter/IncidentReporter/Components/<Category>/<ComponentName>.swift`.
3. **Follow Standard Template**:
   ```swift
   import SwiftUI

   /// Summary description of component
   struct ExampleBadge: View {
       let title: LocalizedStringKey
       var isProminent: Bool = false

       var body: some View {
           Text(title)
               .font(.caption.bold())
               .padding(.horizontal, 8)
               .padding(.vertical, 4)
               .background(isProminent ? Color.accentColor : Color.secondary.opacity(0.2))
               .foregroundStyle(isProminent ? .white : .primary)
               .clipShape(Capsule())
       }
   }

   #Preview {
       VStack(spacing: 8) {
           ExampleBadge(title: "Default")
           ExampleBadge(title: "Prominent", isProminent: true)
       }
       .padding()
   }
   ```
4. **Update Views**: Replace inline UI code in the target views (`Views/`) with the new component.
5. **Verify**: Run `BuildProject` using `xcode-tools` to ensure zero compilation errors.
