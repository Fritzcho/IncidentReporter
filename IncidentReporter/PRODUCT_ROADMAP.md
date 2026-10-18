# IncidentReporter: Product Strategy, Roadmap & Implementation Guide

## Executive Summary & Vision

**IncidentReporter** is a personal safety and incident mapping iOS application tailored for individuals—specifically women traveling alone at night—to report, view, and avoid nearby threats and safety hazards. By combining crowdsourced community reports with verified live data from the Swedish Police API (`polisen.se`), the application aims to transform passive anxiety into proactive, informed personal safety.

---

## 1. Feature Opportunities & Expansion

### Category A: Active Travel & Companion Features
* **"Walk With Me" / Live Guardian Sharing:** 
  * Allows users to share a temporary, secure tracking link with trusted contacts ("guardians") during nighttime transit.
  * Real-time GPS stream with automatic notifications upon arrival, significant route deviation, or unexpected stops.
* **Safety Timer / Check-in Deadlines:** 
  * A countdown timer for nighttime walks (e.g., *"Check in within 20 minutes"*).
  * Requires Face ID, Touch ID, or a PIN to disarm.
  * If the timer expires without confirmation, emergency contacts are alerted with last-known coordinates and a loud local alarm sounds.
* **"Safe Route" Navigation (Pedestrian Routing Engine):** 
  * Standard navigation optimizes strictly for speed or distance, often routing pedestrians through unlit alleys, secluded parks, or industrial paths.
  * A safety-weighted routing engine evaluates candidate paths against recent incident density, verified street lighting, and open businesses.

### Category B: Immediate Defense & Discreet Actions
* **Discreet Fake Call:** 
  * A one-tap tool that schedules or immediately triggers an authentic iOS incoming call screen via CallKit.
  * When answered, realistic pre-recorded audio plays through the earpiece speaker to simulate an ongoing conversation with a friend or partner.
* **Hardware & Gesture Triggers:** 
  * Quick-trigger emergency actions via iPhone Action Button shortcuts, Control Center / Lock Screen widgets, or severe phone shaking.
  * Initiates background audio recording, sends distress messages, or displays emergency contacts.
* **"Safe Havens" Layer (*Trygga platser*):** 
  * An opt-in map overlay highlighting verified open 24/7 or late-night locations: convenience stores (Pressbyrån, 7-Eleven), night pharmacies, hotels, open transit ticket halls, and staffed stations.

### Category C: Community & Data Quality
* **Incident Expiry & Dynamic Decay:** 
  * Loitering groups, transit disturbances, and broken lights are dynamic. 
  * Automatic time-decay (e.g., fading markers after 4–12 hours, archiving after 24–48 hours) prevents persistent stigmatization of neighborhoods.
* **Community Verification ("Still There?" / "Safe Now"):** 
  * Passersby can confirm or resolve active hazard pins with a single tap, increasing data accuracy and trust.
* **Audio Voice Memos:** 
  * Quick hands-free voice notes attached to incident reports for users who cannot safely type details while walking.

### Category D: Apple Ecosystem Integration
* **Apple Watch Companion:** Haptic alerts on wrist when approaching reported danger zones; SOS complication; one-tap check-in.
* **Live Activities & Dynamic Island:** Real-time distance countdown to home and live proximity alerts without unlocking the phone.
* **Interactive Lock Screen Widgets:** Immediate access to report danger or start a safety walk.

---

## 2. Technical Feasibility & Implementation Analysis

| Feature | Category | Difficulty | Backend Required? | Key Frameworks & APIs | Estimated Effort |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Safety Timer / Check-in** | A | Easy – Medium | No (Local-first) | `ActivityKit`, `UserNotifications`, `SwiftUI` | 2 – 3 days |
| **Live Guardian Sharing** | A | Hard | Yes (Cloud sync/web) | `CoreLocation` (Background), Supabase / Firebase, Web Viewer | 2 – 3 weeks |
| **Safe Route Navigation** | A | Hard | Optional | `MapKit` (`MKDirections`), Polyline proximity analysis | 1.5 – 2 weeks |
| **Discreet Fake Call** | B | Medium | No | `CallKit` (`CXProvider`), `AVFoundation` | 3 – 4 days |
| **Hardware / Gesture Triggers** | B | Medium – Hard | No | `CoreMotion`, App Shortcuts (Action Button), WidgetKit | 3 – 5 days |
| **"Safe Havens" Layer** | B | Very Easy | No | `MapKit` (`MKLocalSearch`) or bundled GeoJSON | 1 – 2 days |
| **Incident Expiry & Decay** | C | Very Easy | No | `SwiftData` (`#Predicate`, queries) | 2 – 4 hours |
| **Community Verification** | C | Medium | Yes | `CloudKit` or REST API | 4 – 5 days |
| **Voice Memos / Audio Notes** | C | Easy – Medium | No | `AVFoundation` (`AVAudioRecorder`), `FileManager` | 2 days |

---

### Detailed Implementation Specifications

#### 1. Safety Timer & Check-in (Category A)
* **Architecture:** Entirely on-device. Uses `UNUserNotificationCenter` for high-priority local notifications with custom sound (`UNNotificationSound`).
* **Live Activity:** Implemented via `ActivityKit`. Displays remaining minutes and a quick "Check In" button in Dynamic Island and on the Always-On Display.
* **Escalation:** When time expires, can invoke `MFMessageComposeViewController` or trigger URL scheme `sms:` to send pre-configured distress text with current GPS coordinates.

#### 2. Live Guardian Sharing (Category A)
* **Background Location:** Requires `UIBackgroundModes` with `location` in Info.plist, plus `clManager.allowsBackgroundLocationUpdates = true` and `clManager.showsBackgroundLocationIndicator = true`.
* **Cloud Sync:** Lightweight WebSocket or realtime database (Supabase / Firebase Firestore) receiving updates throttled to every 10–15 seconds or 25 meters.
* **Guardian Web Viewer:** A minimal, responsive map web page (Leaflet / Mapbox) so recipients do not need the iOS app installed to track the walk.

#### 3. Safe Route Navigation (Category A)
* **Strategy:** Query `MKDirections` with `requestsAlternateRoutes = true`.
* **Scoring Algorithm:** Sample points along each returned polyline (`MKPolyline`) and compute shortest Euclidean distance to active `Incident` records.
* **Presentation:** Render candidate routes in SwiftUI Map using `MapPolyline`, highlighting the safest path in emerald green vs. shortest path in neutral gray.

#### 4. Discreet Fake Call (Category B)
* **CallKit Integration:** Use `CXProvider` to report a new incoming call (`reportNewIncomingCall(with:update:completion:)`). This displays the authentic native iOS incoming call screen even when locked.
* **Audio Pipeline:** Configure `AVAudioSession` with `.playAndRecord` and route output to `AVAudioSession.Port.builtInReceiver` (earpiece), playing a conversational audio track.

#### 5. Hardware & Gesture Triggers (Category B)
* **iOS Limitations:** Apple prevents 3rd-party apps from intercepting physical Power Button triple-presses (reserved for OS Emergency SOS).
* **Workaround:** 
  * App Shortcut configured in the Shortcuts app, allowing users to map the physical Action Button (iPhone 15 Pro / 16) directly to "Trigger Safety Walk" or "Fake Call".
  * CoreMotion shake gesture detection within the app.

#### 6. Safe Havens Layer (Category B)
* **Dynamic Search:** Use `MKLocalSearch` with `MKLocalSearch.Request` targeted at `.convenienceStore`, `.pharmacy`, `.police`, `.gasStation`.
* **Static Fallback:** Swedish-curated GeoJSON list of late-night spots (Pressbyrån, 7-Eleven, central station pharmacies).
* **UI:** Toggle button on map overlay rendering green safe badges.

#### 7. Incident Expiry & Verification (Category C)
* **Time Decay:** Add computed property `isExpired: Bool` or SwiftData predicate checking `timestamp >= Calendar.current.date(byAdding: .hour, value: -24, to: Date())!`.
* **CloudKit Sync:** To allow other users to tap "Still an issue" or "All clear", sync an `upvoteCount` and `resolvedCount` via Apple CloudKit public database (`CKContainer.default().publicCloudDatabase`).

#### 8. Voice Memos (Category C)
* Add `NSMicrophoneUsageDescription` to Info.plist.
* Use `AVAudioRecorder` to capture `.m4a` files stored locally under `FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)`.
* Reference file URL in `Incident` model.

---

## 3. Monetization Strategy

> **Core Principle:** Never paywall core personal safety (reporting assault, viewing police data, or receiving immediate proximity alerts). Public trust is essential for community-driven safety apps.

```
┌────────────────────────────────────────────────────────┐
│                   Monetization Streams                  │
├────────────────────┬───────────────────────────────────┤
│ B2C Premium        │ Companion tracking, Watch app,    │
│ (Freemium Sub)     │ fake call, automated SOS dispatch │
├────────────────────┼───────────────────────────────────┤
│ B2B / Duty of Care │ Universities, hospital shifts,    │
│ (SaaS / Licenses)  │ corporate night workers           │
├────────────────────┼───────────────────────────────────┤
│ B2G / Municipal    │ Anonymized safety heatmaps for    │
│ (Kommuner / Urban) │ urban planners & transit (SL)     │
├────────────────────┼───────────────────────────────────┤
│ Hardware Affiliate │ Smart pepper spray (Plegium)      │
│ Partnerships       │ & personal alarm integrations     │
└────────────────────┴───────────────────────────────────┘
```

1. **B2C Freemium ("Guardian Pro" / "Trygghet Plus" - €3.99 – €6.99/mo):**
   * *Free:* Incident viewing, Swedish police feed, reporting incidents, local proximity warnings.
   * *Pro:* Live "Walk With Me" web sharing, Apple Watch companion app, Dynamic Island Live Activities, unlimited Fake Call scenarios, cloud audio recording backup.
2. **B2B Campus & Corporate Duty of Care:**
   * Bulk licenses for universities and student unions (*studentkårer / nationer* in Lund, Uppsala, Stockholm) for student night safety.
   * Employers with late-night shifts (healthcare workers, hospitality, retail closing staff) under Swedish occupational safety (*arbetsmiljöansvar*).
3. **B2G Municipal & Urban Planning Insights (*Kommuner*):**
   * Anonymized, aggregated heatmap data on where safety concerns (broken lighting, loitering, harassment) are repeatedly reported.
   * Sold to municipal city planners (*trygghetsvandringar*) and regional transit authorities (SL, Västtrafik, Skånetrafiken).
4. **Hardware Affiliate Partnerships:**
   * Partner with Swedish safety hardware brands like **Plegium** (Bluetooth smart pepper spray / personal alarms) for in-app hardware pairing and affiliate referral sales.

---

## 4. Marketing & Go-To-Market Strategy

* **Product Viral Loops:**
  * Every time a user initiates a "Walk With Me" session, 2–3 friends/family receive a tracking link with an in-app invite to become a permanent Guardian.
* **University Nightlife Ambassadors:**
  * Target Swedish university cities (Uppsala, Lund, Linköping, Stockholm, Gothenburg) during orientation weeks (*Nollning*) through student unions.
* **Short-Form Video Strategy (TikTok & Instagram Reels):**
  * Practical, highly relatable night safety content: *"Stockholm night safety hacks"*, *"What to do if you're being followed on the green metro line"*, *"How to use the fake call feature"*.
* **Swedish PR & Media Outreach:**
  * Pitch local tech and mainstream publications (Breakit, Aftonbladet, Dagens Nyheter, SVT Nyheter) on civic tech innovation combining Polisen open data with grassroots female safety.
  * Partner with non-profits and anti-violence organizations (*ROKS*, *Unizon*, *Stiftelsen Tryggare Sverige*).

---

## 5. Phased Implementation Roadmap

* **Sprint 1 — Quick On-Device Wins (3–4 days):**
  * Incident Expiry & Time Decay in SwiftData.
  * "Safe Havens" Layer (`MKLocalSearch` / static 24/7 spots).
  * Discreet Fake Call via CallKit.
* **Sprint 2 — Companion & Live Engagement (1–2 weeks):**
  * Safety Timer / Check-in with Lock Screen Live Activity (`ActivityKit`).
  * Audio Voice Memo reporting.
  * Action Button Shortcut integrations.
* **Sprint 3 — Cross-Device Ecosystem & Scale (2–3 weeks):**
  * CloudKit integration for multi-user incident sync and community verification.
  * "Walk With Me" real-time Guardian sharing web link.
  * Apple Watch companion app.
