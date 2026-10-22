import SwiftUI
import MapKit
import SwiftData

struct IncidentMapView: View {
    @Query(sort: \Incident.timestamp, order: .reverse) private var incidents: [Incident]
    @Environment(\.modelContext) private var modelContext

    @State private var locationManager = LocationManager()
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 59.3326, longitude: 18.0649),
            distance: 6000
        )
    )
    @State private var selectedIncident: Incident?
    @State private var selectedSafeHaven: SafeHaven?
    @State private var isPresentingReportSheet = false
    @State private var isPresentingFakeCallLauncher = false
    @State private var isPresentingSafetyTimerSheet = false
    @State private var isSatelliteStyle = false
    @State private var isSyncingPoliceEvents = false
    @State private var safeHavens: [SafeHaven] = SafeHavenService.shared.curatedHavens
    @State private var callService = FakeCallService.shared
    @State private var safetyTimerService = SafetyTimerService.shared
    @State private var quickActionCoordinator = QuickActionCoordinator.shared

    @AppStorage("showPoliceReports") private var showPoliceReports = true
    @AppStorage("showSafeHavens") private var showSafeHavens = true
    @AppStorage("incidentTimeFilter") private var timeFilter: IncidentTimeFilter = .twelveHours
    @AppStorage("shakeTriggerAction") private var shakeTriggerActionRaw: String = ShakeTriggerAction.fakeCall.rawValue

    /// Incidents filtered according to user's police report preferences and time decay window
    private var displayedIncidents: [Incident] {
        incidents.filter { incident in
            if !showPoliceReports && incident.isPoliceReport {
                return false
            }
            if let cutoff = timeFilter.cutoffDate {
                return incident.timestamp >= cutoff
            }
            return true
        }
    }

    /// Filter to only show public transport POIs (bus stops, subways, train stations) and hide restaurants, hotels, etc.
    private let transitOnlyPOIFilter = PointOfInterestCategories.including([.publicTransport])

    var body: some View {
        ZStack {
            mapLayer

            overlayControls
        }
        .sheet(item: $selectedIncident) { incident in
            IncidentDetailSheet(
                incident: incident,
                userLocation: locationManager.userLocation
            )
        }
        .sheet(item: $selectedSafeHaven) { haven in
            SafeHavenDetailSheet(
                haven: haven,
                userLocation: locationManager.userLocation
            )
        }
        .sheet(isPresented: $isPresentingReportSheet) {
            ReportIncidentSheet(
                initialCoordinate: locationManager.userLocation?.coordinate
            )
        }
        .sheet(isPresented: $isPresentingFakeCallLauncher) {
            FakeCallLauncherSheet()
        }
        .sheet(isPresented: $isPresentingSafetyTimerSheet) {
            SafetyTimerSheet(
                userLocation: locationManager.userLocation
            )
        }
        .fullScreenCover(isPresented: Binding(
            get: { callService.isIncomingRinging || callService.isCallActive },
            set: { if !$0 { callService.endCall() } }
        )) {
            FakeCallView()
        }
        .onChange(of: quickActionCoordinator.shouldPresentReportSheet) { _, shouldPresent in
            if shouldPresent {
                quickActionCoordinator.shouldPresentReportSheet = false
                isPresentingReportSheet = true
            }
        }
        .onChange(of: quickActionCoordinator.shouldPresentSafetyTimerSheet) { _, shouldPresent in
            if shouldPresent {
                quickActionCoordinator.shouldPresentSafetyTimerSheet = false
                isPresentingSafetyTimerSheet = true
            }
        }
        .onDeviceShake {
            handleShakeTrigger()
        }
        .task {
            locationManager.requestLocationAuthorization()
            await NotificationService.shared.requestAuthorization()

            // Fetch live Swedish Police events within 50km of user position or Central Stockholm if enabled
            let reference = locationManager.userLocation ?? CLLocation(latitude: 59.3326, longitude: 18.0649)
            if showPoliceReports {
                await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: reference)
            }
            safeHavens = await SafeHavenService.shared.fetchHavens(around: reference.coordinate)
        }
        .onChange(of: locationManager.userLocation) { oldLoc, newLoc in
            locationManager.checkProximity(to: displayedIncidents)

            // When new GPS fix is received on launch, sync police events & safe havens around user coordinates
            if let newLoc, oldLoc == nil {
                let inSweden = newLoc.coordinate.latitude >= 55.0 &&
                               newLoc.coordinate.latitude <= 70.0 &&
                               newLoc.coordinate.longitude >= 10.0 &&
                               newLoc.coordinate.longitude <= 25.0
                if inSweden {
                    withAnimation {
                        cameraPosition = .userLocation(fallback: .camera(MapCamera(centerCoordinate: newLoc.coordinate, distance: 5000)))
                    }
                }
                Task {
                    if showPoliceReports {
                        await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: newLoc)
                    }
                    safeHavens = await SafeHavenService.shared.fetchHavens(around: newLoc.coordinate)
                }
            }
        }
        .onChange(of: incidents) { _, _ in
            locationManager.checkProximity(to: displayedIncidents)
        }
        .onChange(of: timeFilter) { _, _ in
            locationManager.checkProximity(to: displayedIncidents)
            if let selected = selectedIncident, !displayedIncidents.contains(where: { $0.id == selected.id }) {
                selectedIncident = nil
            }
        }
        .onChange(of: showPoliceReports) { _, isEnabled in
            locationManager.checkProximity(to: displayedIncidents)
            if !isEnabled, let selected = selectedIncident, selected.isPoliceReport {
                selectedIncident = nil
            } else if isEnabled {
                Task {
                    isSyncingPoliceEvents = true
                    let reference = locationManager.userLocation ?? CLLocation(latitude: 59.3326, longitude: 18.0649)
                    await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: reference)
                    isSyncingPoliceEvents = false
                }
            }
        }
    }

    // MARK: - Subviews
    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            // Danger & incident annotations
            ForEach(displayedIncidents) { incident in
                Annotation(incident.title, coordinate: incident.coordinate) {
                    annotationView(for: incident)
                }
            }

            // Trygga platser / Safe havens annotations
            if showSafeHavens {
                ForEach(safeHavens) { haven in
                    Annotation(haven.name, coordinate: haven.coordinate) {
                        SafeHavenAnnotationView(
                            haven: haven,
                            isSelected: selectedSafeHaven?.id == haven.id
                        )
                        .onTapGesture {
                            selectedSafeHaven = haven
                        }
                    }
                }
            }
        }
        .mapStyle(
            isSatelliteStyle
                ? .hybrid(elevation: .realistic, pointsOfInterest: transitOnlyPOIFilter)
                : .standard(elevation: .realistic, pointsOfInterest: transitOnlyPOIFilter)
        )
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
            MapPitchToggle()
        }
    }

    private func annotationView(for incident: Incident) -> some View {
        IncidentAnnotationView(
            incident: incident,
            isSelected: selectedIncident?.id == incident.id
        )
        .onTapGesture {
            selectedIncident = incident
        }
    }

    private var overlayControls: some View {
        VStack {
            if safetyTimerService.isActive {
                ActiveSafetyTimerBanner(
                    formattedTime: safetyTimerService.formattedRemainingTime,
                    destinationNote: safetyTimerService.destinationNote,
                    isExpiringSoon: safetyTimerService.state == .expiringSoon,
                    isEscalated: safetyTimerService.state == .escalated,
                    onAddFiveMinutes: {
                        safetyTimerService.addFiveMinutes()
                    },
                    onCheckInSafe: {
                        safetyTimerService.disarmWithBiometrics()
                    },
                    onOpenDetails: {
                        isPresentingSafetyTimerSheet = true
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }

            if let approaching = locationManager.approachingIncident {
                ApproachingIncidentBanner(
                    incident: approaching,
                    userLocation: locationManager.userLocation
                ) {
                    withAnimation {
                        locationManager.dismissApproachingIncident()
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }
            
            // Satellite vs Standard map style toggle
            // MapStyleToggleButton(isSatelliteStyle: $isSatelliteStyle)

            Spacer()

            VStack(alignment: .trailing, spacing: 12) {
                // Sync Swedish Police events button (available when police reports are enabled)
                if showPoliceReports {
                    PoliceSyncButton(isSyncing: isSyncingPoliceEvents) {
                        Task {
                            isSyncingPoliceEvents = true
                            let reference = locationManager.userLocation ?? CLLocation(latitude: 59.3326, longitude: 18.0649)
                            await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: reference, force: true)
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            isSyncingPoliceEvents = false
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Toggle Swedish Police API reports button
                PoliceFilterButton(showPoliceReports: $showPoliceReports)
                

                // Toggle Trygga platser (Safe Havens) button
                SafeHavensFilterButton(showSafeHavens: $showSafeHavens)

                // Safety Walk Timer button
                SafetyTimerButton(
                    isActive: safetyTimerService.isActive,
                    isEscalated: safetyTimerService.state == .escalated
                ) {
                    isPresentingSafetyTimerSheet = true
                }

                // Discreet Fake Call button
                DiscreetCallButton {
                    isPresentingFakeCallLauncher = true
                }

                // Filter incidents by recency / time decay
                TimeFilterMenuButton(timeFilter: $timeFilter)


                ReportDangerButton {
                    isPresentingReportSheet = true
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 14)
            .padding(.bottom, 24)
        }
    }

    private func handleShakeTrigger() {
        let action = ShakeTriggerAction(rawValue: shakeTriggerActionRaw) ?? .fakeCall
        guard action != .disabled else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        switch action {
        case .disabled:
            break
        case .fakeCall:
            let caller = UserDefaults.standard.string(forKey: "fakeCallerName") ?? "Emma"
            callService.scheduleCall(delaySeconds: 0, caller: caller)
        case .reportDanger:
            isPresentingReportSheet = true
        case .startSafetyTimer:
            if !safetyTimerService.isActive {
                safetyTimerService.startTimer(minutes: 20, destination: "Home")
            } else {
                isPresentingSafetyTimerSheet = true
            }
        }
    }
}
