# IncidentReporter 🛡️

**IncidentReporter** is a personal safety and incident awareness iOS application tailored for individuals—specifically people navigating unfamiliar or nighttime urban environments—to report, view, and avoid nearby safety hazards.

By combining community crowdsourcing with live verified data from the **Swedish Police API (`polisen.se`)**, IncidentReporter bridges the gap between passive anxiety and informed, proactive personal safety.

---

## ✨ Key Features

- **🗺️ Interactive Safety Map:** Real-time MapKit interface rendering incident clusters, danger categories, and verified locations.
- **🚔 Swedish Police API Integration:** Automatically fetches, geocodes, and synchronizes live events from the Swedish Police API within a customizable radius (e.g., Greater Stockholm).
- **🏪 Safe Havens Layer (*Trygga platser*):** Toggleable overlay highlighting nearby 24/7 or late-night secure venues (convenience stores, 24/7 pharmacies, staffed transit stations, and police stations).
- **📞 Discreet Fake Call:** Fast-access simulated incoming call designed to help users safely exit uncomfortable or suspicious situations.
- **🚨 Proximity Warnings:** Automatic banner and notification alerts when approaching active incident zones.
- **🕒 Time-Based Filters:** Filter incidents by freshness (past 6h, 12h, 24h, or all active records).
- **📝 Incident Reporting:** Quick report flow allowing users to pin danger categories (Harassment, Theft, Assault, Suspicious Activity, Poor Lighting, etc.) with custom severity ratings.
- **🌐 Localization:** Full Swedish (*Svenska*) and English localization via native Xcode String Catalogs (`.xcstrings`).

---

## 🛠️ Architecture & Tech Stack

- **UI Framework:** SwiftUI
- **Local Persistence:** SwiftData (`@Model`, `ModelContainer`)
- **Maps & Location:** MapKit, CoreLocation (`CLLocationManager`)
- **Networking:** Native `async`/`await` `URLSession` consuming `polisen.se` REST endpoints
- **Audio & System Services:** AVFoundation, UserNotifications
- **Language Support:** Swift 5.9+ / Swift 6 ready

---

## 📂 Project Structure

```
IncidentReporter/
├── IncidentReporter/
│   ├── MyApp.swift                      # App entry point & SwiftData container init
│   ├── ContentView.swift                # Root TabView (Map, Incident List)
│   ├── Models/
│   │   ├── Incident.swift               # SwiftData model for incidents
│   │   ├── IncidentCategory.swift       # Categories & icon mappings
│   │   ├── IncidentSeverity.swift       # Severity scale (Low to Critical)
│   │   ├── IncidentTimeFilter.swift     # Time filter options
│   │   └── SafeHaven.swift              # Safe haven places model
│   ├── Views/
│   │   ├── IncidentMapView.swift        # Primary map interface & floating controls
│   │   ├── IncidentListView.swift       # Filterable and searchable incident list
│   │   ├── IncidentDetailSheet.swift    # Detailed incident metadata modal
│   │   ├── ReportIncidentSheet.swift    # User report submission flow
│   │   ├── SafeHavenDetailSheet.swift   # Safe haven information modal
│   │   ├── FakeCallView.swift           # Native-styled simulated incoming call
│   │   └── SettingsView.swift           # User preferences & language switcher
│   ├── Components/
│   │   ├── Badges/                      # Police & severity indicators
│   │   ├── Buttons/                     # Map controls & action triggers
│   │   ├── Cards/                       # Detail header components
│   │   ├── Icons/                       # Category icon visualizers
│   │   └── Rows/                        # List and metadata rows
│   ├── Services/
│   │   ├── PoliceAPIService.swift       # Swedish police API sync & JSON decoder
│   │   ├── IncidentRepository.swift     # SwiftData query helper
│   │   ├── LocationManager.swift        # GPS tracking & proximity triggers
│   │   ├── NotificationService.swift    # Local push notification manager
│   │   ├── FakeCallService.swift        # Simulated call scheduler & audio
│   │   └── SafeHavenService.swift       # Curated safe haven locations provider
│   ├── Localizable.xcstrings            # App UI strings (EN / SV)
│   └── IncidentReporter-InfoPlist.xcstrings # Privacy permissions text
└── IncidentReporter.xcodeproj
```

---

## 🚀 Getting Started

### Prerequisites

- **macOS Sonoma (14.0+)** or later
- **Xcode 15.0+**
- **iOS 17.0+** deployment target

### Setup & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Fritzcho/IncidentReporter.git
   cd IncidentReporter
   ```

2. **Open the project in Xcode:**
   ```bash
   open IncidentReporter.xcodeproj
   ```

3. **Select a Target & Destination:**
   - Select the `IncidentReporter` scheme.
   - Choose an iOS Simulator (e.g. iPhone 15 Pro, iOS 17+) or a connected physical device.

4. **Build and Run:**
   - Press `Cmd + R` to compile and run.

---

## 🔒 Permissions & Privacy

The app requires standard location permissions to compute proximity to nearby incidents and display current position on the map:
- `NSLocationWhenInUseUsageDescription`: Required to show current location on the incident map and trigger proximity alerts.
- `NSLocationAlwaysAndWhenInUseUsageDescription`: Optional for future background companion / guardian features.

---

## 📖 Product Roadmap

Refer to [PRODUCT_ROADMAP.md](file:///Users/alir/Documents/Privat/iosApp/IncidentReporter/IncidentReporter/PRODUCT_ROADMAP.md) for future feature specifications including CallKit-based fake calls, Live Activities / Dynamic Island companion tracking, and safety-weighted routing.

---

## 📄 License

This project is licensed under the MIT License - see the repository settings for details.
