# AGENTS.md — Instructions for AI Coding Assistants

Welcome to the **IncidentReporter** iOS codebase. This repository follows strict SwiftUI architectural patterns, design standards, and folder organizations. When adding features, components, or refactoring code, adhere to the guidelines below.

---

## 1. Project Overview & Architecture

- **Platform**: iOS 17+ (Swift 5.9 / Swift 6 mode)
- **Frameworks**: SwiftUI, SwiftData, MapKit, CoreLocation
- **Project Structure**:
  - `IncidentReporter/Components/`: Modular, reusable UI components categorized by visual type.
  - `IncidentReporter/Views/`: Screen-level containers and sheets (e.g. `IncidentMapView`, `IncidentListView`, `ReportIncidentSheet`, `SettingsView`).
  - `IncidentReporter/Models/`: SwiftData models and core enums (`Incident`, `IncidentCategory`, `IncidentSeverity`).
  - `IncidentReporter/Services/`: Backend and device services (`PoliceAPIService`, `LocationManager`, `NotificationService`, `IncidentRepository`).

---

## 2. Component Guidelines & Folder Structure

All reusable visual elements, buttons, badges, inputs, and rows **must reside in `IncidentReporter/Components/`** under their corresponding subfolder. **Never place `.swift` component files directly in the root of `Components/`.**

```text
IncidentReporter/Components/
├── Badges/      # Informational indicators, status tags, threat levels (e.g. PoliceBadge, SeverityBadge)
├── Buttons/     # Action buttons, map controls, custom ButtonStyles (e.g. ReportDangerButton, MapStyleToggleButton)
├── Cards/       # Card containers, preview summaries, card headers (e.g. IncidentDetailHeaderView)
├── Icons/       # Category symbols, visual glyphs (e.g. CategoryIconView)
├── Inputs/      # Input fields, geocoding search rows, location summaries (e.g. CustomAddressInputView, CurrentLocationDisplayView)
└── Rows/        # List items, key-value rows, settings rows (e.g. IncidentRowView, IncidentMetadataRow, LanguageSelectionRow)
```

### Classification Matrix

When creating a new component, use this decision matrix:

| If your component is... | Place it in... | Example |
| :--- | :--- | :--- |
| A clickable action, toggle, or `ButtonStyle` | `Components/Buttons/` | `PrimaryCapsuleButton.swift` |
| A pill, chip, status tag, or severity pill | `Components/Badges/` | `StatusBadge.swift` |
| An icon circle, category glyph, or symbol | `Components/Icons/` | `IncidentCategoryIcon.swift` |
| A card surface, card container, or card header | `Components/Cards/` | `IncidentCardView.swift` |
| A form input, text field, picker row, or search field | `Components/Inputs/` | `CoordinateInputField.swift` |
| A list row, table cell, or key-value metadata item | `Components/Rows/` | `IncidentHistoryRow.swift` |

---

## 3. Code Standards for Components

1. **Pure Presentation & Single Responsibility**:
   - Reusable components must not directly trigger network calls, execute SwiftData `@Query` logic, or perform side-effects unless passed via closure callbacks (e.g. `let onAction: () -> Void`).
   - Pass read-only model data via `let` constants.
   - Use `@Binding` for state that is owned and managed by the parent view.
   - Use `@State private var` strictly for internal UI/animation state.

2. **Localization**:
   - Never hardcode user-facing strings.
   - Use `LocalizedStringKey` or standard `String` keys matching `Localizable.xcstrings`.

3. **Accessibility**:
   - Provide `.accessibilityLabel` for icon-only buttons and indicators.
   - Respect system dynamic type sizes and high-contrast modes.

4. **Formatting & Documentation**:
   - 4-space indentation.
   - Include a DocC documentation comment (`/// ...`) describing the component.
   - Always include a `#Preview` demonstrating different states (e.g., loading, active, disabled, compact vs regular).

---

## 4. Xcode Tooling for AI Agents

When interacting with this codebase:
- Use **`xcode-tools`** MCP tools (`XcodeRead`, `XcodeWrite`, `XcodeUpdate`, `XcodeMV`, `XcodeMakeDir`, `BuildProject`).
- To create a new component:
  1. Determine the correct subfolder under `IncidentReporter/IncidentReporter/Components/<Category>/`.
  2. Call `XcodeWrite` with the project-relative path. `XcodeWrite` automatically registers the file in the Xcode project structure.
  3. Validate by running `BuildProject` from `xcode-tools` and check for 0 errors.
