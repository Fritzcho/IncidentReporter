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
    @State private var selectedTransitStop: TransitStop?
    /// Safety-related SL disruptions (police operations, people on the tracks…) at the stops they affect
    @State private var transitAlerts: [TransitSafetyAlert] = []
    @State private var selectedTransitAlert: TransitSafetyAlert?
    @State private var transitStops: [TransitStop] = []
    @State private var isLoadingTransit = false
    @State private var isPresentingStopSearch = false
    /// A transit icon drawn by Apple Maps that the user tapped
    @State private var selectedMapFeature: MapFeature?
    /// Visible map area, used to draw every SL stop in view when zoomed in
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var visibleStops: [TransitStopSummary] = []
    @State private var loadingStopID: Int?
    @State private var isPresentingReportSheet = false
    @State private var isPresentingFakeCallLauncher = false
    @State private var isPresentingSafetyTimerSheet = false
    @State private var isPresentingTaxiLauncher = false
    @State private var isSatelliteStyle = false
    @State private var isSyncingPoliceEvents = false
    @State private var safeHavens: [SafeHaven] = SafeHavenService.shared.curatedHavens
    @State private var callService = FakeCallService.shared
    @State private var safetyTimerService = SafetyTimerService.shared
    @State private var quickActionCoordinator = QuickActionCoordinator.shared
    @State private var ignoredStore = IgnoredIncidentStore.shared
    @State private var myPlaces = MyPlacesStore.shared
    @State private var isPresentingRouteSearch = false
    /// Where the active safe route goes; nil when no route is shown
    @State private var routeDestination: MKMapItem?
    /// Where the active safe route starts; nil means the user's own position
    @State private var routeOrigin: MKMapItem?
    /// Dangers known when the route was last planned, to spot new ones on it
    @State private var plannedDangerIDs: Set<String> = []
    /// Latest change on the active route, shown as a banner
    @State private var routeUpdate: RouteUpdate?
    /// Walking or public transport for the active route
    @State private var routeMode: RouteMode = .walk
    @State private var selectedTripID: String?
    @State private var isPresentingRouteDetails = false
    /// Bumped every couple of minutes during a route to re-plan with fresh real-time departures
    @State private var routeRefreshTick = 0
    @Environment(\.scenePhase) private var scenePhase
    @State private var routePlan: SafeRoutePlan?
    @State private var isPlanningRoute = false
    @State private var routeErrorMessage: String?

    @AppStorage("showPoliceReports") private var showPoliceReports = true
    @AppStorage("showSafeHavens") private var showSafeHavens = true
    @AppStorage("showTransitAlerts") private var showTransitAlerts = true
    @AppStorage("safeHavensOpenNowOnly") private var safeHavensOpenNowOnly = false
    // Preferences from My page
    @AppStorage("routeCaution") private var routeCaution: RouteCaution = .balanced
    @AppStorage("preferredTravelMode") private var preferredTravelMode: PreferredTravelMode = .automatic
    @AppStorage("proximityAlertsEnabled") private var proximityAlertsEnabled = true
    @AppStorage("proximityAlertDistance") private var proximityAlertDistance = 500.0
    @AppStorage("routeAlertsEnabled") private var routeAlertsEnabled = true
    /// Comma-separated `TransitMode` raw values the user has chosen to see on the map
    @AppStorage("visibleTransitModes") private var visibleTransitModesRaw =
        TransitMode.defaultVisibleModes.map(\.rawValue).joined(separator: ",")
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

    /// Displayed incidents the user hasn't marked as over; only these trigger proximity alerts
    private var activeIncidents: [Incident] {
        displayedIncidents.filter { !ignoredStore.isIgnored($0) }
    }

    /// Safe havens to draw: fewer the further out the map is zoomed, keeping the most useful
    /// (police and hospitals before shops, open before closed) and leaving hotels for close zoom.
    private var displayedHavens: [SafeHaven] {
        guard showSafeHavens else { return [] }
        let now = Date()
        var candidates = safeHavensOpenNowOnly ? safeHavens.filter { $0.isOpen(at: now) == true } : safeHavens
        guard let region = visibleRegion else { return Array(candidates.prefix(30)) }
        let span = region.span.latitudeDelta
        if span > 0.015 {
            candidates = candidates.filter { $0.category != .hotel }
        }
        let columns: Int
        switch span {
        case ..<0.006: columns = 12
        case ..<0.015: columns = 7
        case ..<0.04: columns = 5
        case ..<0.1: columns = 3
        default: columns = 2
        }
        return MapDeclutter.thin(candidates, in: region, columns: columns, coordinate: \.coordinate) { haven in
            Self.havenRank(haven, at: now)
        }
        .map(\.item)
    }

    /// Lower is more important: the kind of place first, then whether it's known to be open now
    private static func havenRank(_ haven: SafeHaven, at date: Date) -> Double {
        let kind: Double
        switch haven.category {
        case .policeStation: kind = 0
        case .hospital: kind = 1
        case .transitHub: kind = 2
        case .pharmacy: kind = 3
        case .convenienceStore: kind = 4
        case .hotel: kind = 6
        }
        let openness: Double
        switch haven.isOpen(at: date) {
        case true?: openness = 0
        case nil: openness = 5
        case false?: openness = 20
        }
        return openness + kind
    }

    /// Danger pins to draw. Zoomed in, every one; further out, the most serious and recent in each
    /// part of the map, with a count of the others nearby.
    private var incidentPins: [MapDeclutter.Pin<Incident>] {
        guard let region = visibleRegion, region.span.latitudeDelta > 0.02 else {
            return displayedIncidents.map { MapDeclutter.Pin(item: $0, hiddenCount: 0) }
        }
        let columns = region.span.latitudeDelta > 0.06 ? 4 : 6
        return MapDeclutter.thin(displayedIncidents, in: region, columns: columns, coordinate: \.coordinate) { incident in
            let severity: Double
            switch incident.severity {
            case .high: severity = 0
            case .medium: severity = 1
            case .low: severity = 2
            }
            return (ignoredStore.isIgnored(incident) ? 1000 : 0) + severity * 100 + incident.hoursAgo
        }
    }

    /// SL stop markers to draw: all when zoomed right in, otherwise one per part of the map,
    /// subway and train stations first
    private var displayedStopMarkers: [TransitStopSummary] {
        let markers = stopMarkers.filter { $0.primaryMode(in: visibleTransitModes) != nil }
        guard let region = visibleRegion, region.span.latitudeDelta > 0.008 else { return markers }
        return MapDeclutter.thin(markers, in: region, columns: 7, coordinate: \.coordinate) { stop in
            Double(stop.primaryMode(in: visibleTransitModes).flatMap { TransitMode.allCases.firstIndex(of: $0) } ?? 9)
        }
        .map(\.item)
    }

    /// Zooms in a few steps around a spot, e.g. a danger pin that stands for several others
    private func zoomIn(on coordinate: CLLocationCoordinate2D) {
        guard let region = visibleRegion else { return }
        let span = MKCoordinateSpan(
            latitudeDelta: max(region.span.latitudeDelta / 3, Self.minimumOverlapZoomSpan),
            longitudeDelta: max(region.span.longitudeDelta / 3, Self.minimumOverlapZoomSpan)
        )
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: span))
        }
    }

    /// Changes when the map moves to a new ~2 km area, so safe havens there get loaded
    private var havenAreaKey: String {
        guard showSafeHavens, let region = visibleRegion, region.span.latitudeDelta <= 0.12 else { return "none" }
        return "\(Int((region.center.latitude * 50).rounded()))-\(Int((region.center.longitude * 25).rounded()))"
    }

    /// Adds the safe havens around `coordinate` to those already on the map
    private func loadSafeHavens(around coordinate: CLLocationCoordinate2D) async {
        let found = await SafeHavenService.shared.fetchHavens(around: coordinate)
        safeHavens = SafeHavenService.merged(safeHavens + found)
    }

    private var displayedTransitAlerts: [TransitSafetyAlert] {
        showTransitAlerts ? transitAlerts : []
    }

    /// Dangers the safe route steers around: every report from the last 24 hours and every active
    /// SL safety alert the user hasn't marked as over, whatever the map filters show
    private var routeDangers: [RouteDanger] {
        let weight = routeCaution.penaltyWeight
        let reported = incidents
            .filter { !$0.isExpired && !ignoredStore.isIgnored($0) }
            .map { RouteDanger(incident: $0, weight: weight) }
        let alerts = transitAlerts
            .filter { !ignoredStore.isIgnored(key: $0.ignoreKey) }
            .map { RouteDanger(alert: $0, weight: weight) }
        return reported + alerts
    }

    /// Re-plans the route when the destination or the set of dangers changes
    private var routeKey: String {
        guard let destination = routeDestination?.location.coordinate else { return "none" }
        let origin = routeOrigin.map { "\($0.location.coordinate.latitude),\($0.location.coordinate.longitude)" } ?? "me"
        let dangerIDs = routeDangers.map(\.id).sorted().joined(separator: ",")
        return "\(origin)-\(destination.latitude),\(destination.longitude)-\(dangerIDs.hashValue)-\(routeCaution.rawValue)-\(routeRefreshTick)"
    }

    private var visibleTransitModes: Set<TransitMode> {
        Set(visibleTransitModesRaw.split(separator: ",").compactMap { TransitMode(rawValue: String($0)) })
    }

    private var visibleTransitModesBinding: Binding<Set<TransitMode>> {
        Binding(
            get: { visibleTransitModes },
            set: { modes in
                visibleTransitModesRaw = TransitMode.allCases
                    .filter { modes.contains($0) }
                    .map(\.rawValue)
                    .joined(separator: ",")
            }
        )
    }

    private var showTransit: Bool { !visibleTransitModes.isEmpty }

    /// Reference point for the nearest-stop search: the user's position, or Central Stockholm
    private var transitReferenceLocation: CLLocation {
        locationManager.userLocation ?? CLLocation(latitude: 59.3326, longitude: 18.0649)
    }

    /// Changes when the user moves roughly 200 m, so nearest stops are re-resolved without re-querying on every GPS fix
    private var transitSearchKey: String {
        let coordinate = transitReferenceLocation.coordinate
        return "\(visibleTransitModesRaw)-\(Int(coordinate.latitude * 500))-\(Int(coordinate.longitude * 250))"
    }

    /// Stop markers are only drawn when the map shows roughly 3 km or less, to keep the map readable
    private static let stopMarkerMaxSpan: CLLocationDegrees = 0.03

    /// Changes when the user pans or zooms meaningfully, so stop markers reload without thrashing
    private var visibleStopsKey: String {
        guard showTransit, let region = visibleRegion else { return "hidden" }
        guard region.span.latitudeDelta <= Self.stopMarkerMaxSpan else { return "zoomed-out" }
        return "\(visibleTransitModesRaw)-\(Int(region.center.latitude * 2000))-\(Int(region.center.longitude * 1000))-\(Int(region.span.latitudeDelta * 2000))"
    }

    /// Visible stop markers, minus stops that already have a nearest-stop pin
    private var stopMarkers: [TransitStopSummary] {
        let pinned = Set(transitStops.map(\.id))
        return visibleStops.filter { !pinned.contains($0.id) }
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
        .sheet(item: $selectedTransitAlert) { alert in
            TransitAlertDetailSheet(alert: alert, userLocation: locationManager.userLocation)
        }
        .sheet(item: $selectedTransitStop) { stop in
            TransitStopDetailSheet(
                stop: stop,
                userLocation: locationManager.userLocation
            )
        }
        .sheet(isPresented: $isPresentingReportSheet) {
            ReportIncidentSheet(
                initialCoordinate: locationManager.userLocation?.coordinate
            )
        }
        .sheet(isPresented: $isPresentingStopSearch) {
            TransitStopSearchSheet(userLocation: locationManager.userLocation)
        }
        .sheet(isPresented: $isPresentingRouteSearch) {
            SafeRouteSearchSheet(
                userLocation: locationManager.userLocation,
                origin: routeOrigin,
                destination: routeDestination,
                home: myPlaces.effectiveHome,
                isTemporaryHome: myPlaces.activeTemporaryHome != nil,
                savedPlaces: myPlaces.places
            ) { origin, destination in
                routePlan = nil
                routeOrigin = origin
                routeDestination = destination
            }
        }
        .sheet(isPresented: $isPresentingRouteDetails) {
            if let routePlan {
                RouteDetailSheet(plan: routePlan, mode: $routeMode, selectedTripID: $selectedTripID)
            }
        }
        .sheet(isPresented: $isPresentingTaxiLauncher) {
            TaxiLauncherSheet(userLocation: locationManager.userLocation)
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
            await loadSafeHavens(around: reference.coordinate)
        }
        .task(id: transitSearchKey) {
            await refreshTransitStops()
        }
        .task(id: visibleStopsKey) {
            await loadVisibleStops()
        }
        .task(id: routeKey) {
            await planRoute()
        }
        .task {
            await refreshTransitAlerts()
        }
        .task(id: havenAreaKey) {
            guard havenAreaKey != "none", let center = visibleRegion?.center else { return }
            // Let panning settle before querying
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await loadSafeHavens(around: center)
        }
        .task(id: routeDestination != nil) {
            await watchActiveRoute()
        }
        .onChange(of: selectedMapFeature) { _, feature in
            guard let feature else { return }
            Task { await openDepartures(for: feature) }
        }
        .onChange(of: locationManager.userLocation) { oldLoc, newLoc in
            locationManager.checkProximity(to: activeIncidents)

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
                    await loadSafeHavens(around: newLoc.coordinate)
                }
            }
        }
        .task(id: "\(proximityAlertsEnabled)-\(proximityAlertDistance)") {
            locationManager.proximityAlertsEnabled = proximityAlertsEnabled
            locationManager.proximityThresholdMeters = proximityAlertDistance
            if !proximityAlertsEnabled {
                locationManager.dismissApproachingIncident()
            }
        }
        .onChange(of: incidents) { _, _ in
            locationManager.checkProximity(to: activeIncidents)
        }
        .onChange(of: ignoredStore.keys) { _, _ in
            if let approaching = locationManager.approachingIncident, ignoredStore.isIgnored(approaching) {
                locationManager.dismissApproachingIncident()
            }
            locationManager.checkProximity(to: activeIncidents)
        }
        .onChange(of: timeFilter) { _, _ in
            locationManager.checkProximity(to: activeIncidents)
            if let selected = selectedIncident, !displayedIncidents.contains(where: { $0.id == selected.id }) {
                selectedIncident = nil
            }
        }
        .onChange(of: showPoliceReports) { _, isEnabled in
            locationManager.checkProximity(to: activeIncidents)
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
        MapReader { proxy in
            Map(position: $cameraPosition, selection: $selectedMapFeature) {
                UserAnnotation()

                // Safe route: other routes considered faintly, the recommended one on top
                if let routePlan {
                    if let trip = activeTrip?.trip {
                        // Public transport: walks dotted green, rides in their line colour, a marker where to get on
                        ForEach(trip.legs) { leg in
                            if leg.isWalk {
                                MapPolyline(leg.polyline)
                                    .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 8]))
                            } else {
                                MapPolyline(leg.polyline)
                                    .stroke((leg.mode?.color ?? .blue).gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                            }
                        }
                        ForEach(trip.rides) { ride in
                            Marker("\(ride.line ?? "") \(ride.from.name)", systemImage: ride.mode?.systemImage ?? "tram.fill",
                                   coordinate: ride.from.coordinate)
                                .tint(ride.mode?.color ?? .blue)
                        }
                    } else {
                        ForEach(routePlan.alternatives) { route in
                            MapPolyline(route.polyline)
                                .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 6]))
                        }
                        MapPolyline(routePlan.recommended.polyline)
                            .stroke(Color.green.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                    Marker(routePlan.destinationName, systemImage: "flag.checkered", coordinate: routePlan.destination)
                        .tint(.green)
                    if let routeOrigin {
                        Marker(routeOrigin.name ?? String(localized: "Start"), systemImage: "circle.circle.fill",
                               coordinate: routeOrigin.location.coordinate)
                            .tint(.blue)
                    }
                }

                // Danger & incident annotations
                ForEach(incidentPins, id: \.item.id) { pin in
                    let incident = pin.item
                    Annotation(incident.title, coordinate: incident.coordinate) {
                        annotationView(for: incident, hiddenCount: pin.hiddenCount) {
                            // A pin standing for several dangers zooms in to show them all
                            if pin.hiddenCount > 0 {
                                zoomIn(on: incident.coordinate)
                                return
                            }
                            handlePinTap(at: incident.coordinate, proxy: proxy) {
                                selectedIncident = incident
                            }
                        }
                    }
                }

                // Every SL stop in view when zoomed in; tap for departures
                ForEach(displayedStopMarkers) { stop in
                    if let mode = stop.primaryMode(in: visibleTransitModes) {
                        Annotation(stop.name, coordinate: stop.coordinate) {
                            TransitStopMarkerIcon(name: stop.name, mode: mode, isLoading: loadingStopID == stop.id)
                                .onTapGesture {
                                    handlePinTap(at: stop.coordinate, proxy: proxy) {
                                        Task { await openDepartures(for: stop) }
                                    }
                                }
                        }
                        .annotationTitles(.hidden)
                    }
                }

                // Nearest stop for each chosen transit type, with live departures
                if showTransit {
                    ForEach(transitStops) { stop in
                        Annotation(stop.name, coordinate: stop.coordinate) {
                            TransitStopAnnotationView(
                                stop: stop,
                                isSelected: selectedTransitStop?.id == stop.id
                            )
                            .onTapGesture {
                                handlePinTap(at: stop.coordinate, proxy: proxy) {
                                    selectedTransitStop = stop
                                }
                            }
                        }
                    }
                }

                // Trygga platser / Safe havens annotations
                if showSafeHavens {
                    ForEach(displayedHavens) { haven in
                        Annotation(haven.name, coordinate: haven.coordinate) {
                            SafeHavenAnnotationView(
                                haven: haven,
                                isSelected: selectedSafeHaven?.id == haven.id
                            )
                            .onTapGesture {
                                handlePinTap(at: haven.coordinate, proxy: proxy) {
                                    selectedSafeHaven = haven
                                }
                            }
                        }
                    }
                }

                // SL safety alerts: police operations, people on the tracks, evacuations…
                // Drawn last and raised above the point, so the station's own pin doesn't cover them
                ForEach(displayedTransitAlerts) { alert in
                    Annotation(alert.header, coordinate: alert.coordinate, anchor: .bottom) {
                        let isIgnored = ignoredStore.isIgnored(key: alert.ignoreKey)
                        TransitAlertAnnotationView(alert: alert, isSelected: selectedTransitAlert?.id == alert.id)
                            .grayscale(isIgnored ? 1 : 0)
                            .opacity(isIgnored ? 0.4 : 1)
                            .onTapGesture {
                                selectedTransitAlert = alert
                            }
                            .padding(.bottom, 26)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(
                isSatelliteStyle
                    ? .hybrid(elevation: .realistic, pointsOfInterest: transitOnlyPOIFilter)
                    : .standard(elevation: .realistic, pointsOfInterest: transitOnlyPOIFilter)
            )
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
        }
    }

    // MARK: - Overlapping pins

    /// Pins whose centres are closer than this on screen overlap enough to be hard to tap apart
    private static let pinOverlapDistance: CGFloat = 36
    /// Closest the overlap zoom goes (roughly 150 m across); past this, the tapped pin just opens
    private static let minimumOverlapZoomSpan: CLLocationDegrees = 0.0015

    /// Every pin currently drawn on the map. SL alerts are left out: they float above their station
    private var pinCoordinates: [CLLocationCoordinate2D] {
        var coordinates = incidentPins.map(\.item.coordinate)
        coordinates += displayedStopMarkers.map(\.coordinate)
        if showTransit {
            coordinates += transitStops.map(\.coordinate)
        }
        if showSafeHavens {
            coordinates += displayedHavens.map(\.coordinate)
        }
        return coordinates
    }

    /// Opens a tapped pin, unless other pins overlap it on screen: then zooms in on it first,
    /// so the user can pick the one they meant.
    private func handlePinTap(at coordinate: CLLocationCoordinate2D, proxy: MapProxy, open: () -> Void) {
        guard let region = visibleRegion,
              region.span.latitudeDelta > Self.minimumOverlapZoomSpan,
              let tapped = proxy.convert(coordinate, to: .local) else {
            open()
            return
        }

        let overlapping = pinCoordinates.filter { other in
            guard let point = proxy.convert(other, to: .local) else { return false }
            return hypot(point.x - tapped.x, point.y - tapped.y) < Self.pinOverlapDistance
        }
        // The tapped pin is in the list itself, so overlap means at least two
        guard overlapping.count > 1 else {
            open()
            return
        }

        let span = MKCoordinateSpan(
            latitudeDelta: max(region.span.latitudeDelta / 4, Self.minimumOverlapZoomSpan),
            longitudeDelta: max(region.span.longitudeDelta / 4, Self.minimumOverlapZoomSpan)
        )
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: span))
        }
    }

    // MARK: - Safe route

    /// What the summary card names: the dangers the route still passes, or else the ones it avoids
    private var routeDangerNames: [String] {
        guard let routePlan else { return [] }
        if let activeTrip {
            if !activeTrip.dangersPassed.isEmpty {
                return activeTrip.dangersPassed.map(\.title)
            }
            let passedIDs = Set(activeTrip.dangersPassed.map(\.id))
            let fastest = routePlan.transitTrips.min { ($0.trip.arrival ?? .distantFuture) < ($1.trip.arrival ?? .distantFuture) }
            return (fastest?.dangersPassed ?? []).filter { !passedIDs.contains($0.id) }.map(\.title)
        }
        let dangers = routePlan.recommended.dangersPassed.isEmpty
            ? routePlan.avoidedDangers
            : routePlan.recommended.dangersPassed
        return dangers.map(\.title)
    }

    /// How the followed route compares with the fastest one: extra time, dangers avoided and still passed.
    /// For public transport the comparison is against the trip that arrives first.
    private var routeComparison: (extraTime: TimeInterval, avoided: Int, passed: Int) {
        guard let routePlan else { return (0, 0, 0) }
        guard let activeTrip else {
            return (routePlan.extraTime, routePlan.avoidedDangers.count, routePlan.recommended.dangersPassed.count)
        }
        let fastest = routePlan.transitTrips.min { ($0.trip.arrival ?? .distantFuture) < ($1.trip.arrival ?? .distantFuture) } ?? activeTrip
        let passedIDs = Set(activeTrip.dangersPassed.map(\.id))
        let extra = (activeTrip.trip.arrival ?? .now).timeIntervalSince(fastest.trip.arrival ?? .now)
        return (max(0, extra), fastest.dangersPassed.filter { !passedIDs.contains($0.id) }.count, passedIDs.count)
    }

    /// The public transport trip being followed, or nil when walking
    private var activeTrip: ScoredTransitTrip? {
        guard routeMode == .transit, let trips = routePlan?.transitTrips, !trips.isEmpty else { return nil }
        return trips.first { $0.id == selectedTripID } ?? trips.first
    }

    /// The line the user is following on the map, used to spot new dangers on it
    private func activePolyline(in plan: SafeRoutePlan, tripID: String?) -> MKPolyline {
        if routeMode == .transit, let trip = plan.transitTrips.first(where: { $0.id == tripID }) ?? plan.transitTrips.first {
            return trip.trip.polyline
        }
        return plan.recommended.polyline
    }

    /// Keeps SL safety alerts current while the map is open. A failed fetch keeps the last known alerts.
    private func refreshTransitAlerts() async {
        while !Task.isCancelled {
            if let alerts = try? await SLDeviationService.shared.safetyAlerts() {
                transitAlerts = alerts
            }
            try? await Task.sleep(for: .seconds(90))
        }
    }

    /// Plans (or re-plans, when dangers change) the safe route to `routeDestination`.
    /// The camera is framed on the route only the first time it is planned.
    private func planRoute() async {
        guard let destination = routeDestination else {
            routePlan = nil
            routeErrorMessage = nil
            return
        }
        let previousPlan = routePlan
        let isFirstPlan = previousPlan == nil
        isPlanningRoute = true
        defer { isPlanningRoute = false }
        // Re-plans start where the user is now, so the new route continues from here
        let origin = routeOrigin?.location.coordinate ?? transitReferenceLocation.coordinate
        let dangers = routeDangers
        do {
            let plan = try await SafeRouteService.plan(from: origin, to: destination, avoiding: dangers)
            guard !Task.isCancelled else { return }
            if isFirstPlan {
                // Start the way the user prefers; "fastest" picks public transport when it's clearly sooner
                switch preferredTravelMode {
                case .automatic: routeMode = plan.isTransitFaster ? .transit : .walk
                case .walk: routeMode = .walk
                case .transit: routeMode = plan.transitTrips.isEmpty ? .walk : .transit
                }
                selectedTripID = plan.transitTrips.first?.id
            } else if !plan.transitTrips.contains(where: { $0.id == selectedTripID }) {
                // The chosen departure has left or no longer works: follow the best one now
                selectedTripID = plan.transitTrips.first?.id
            }
            if let previousPlan {
                let fresh = SafeRouteService.newDangers(
                    in: dangers,
                    knownIDs: plannedDangerIDs,
                    near: [activePolyline(in: previousPlan, tripID: selectedTripID), activePolyline(in: plan, tripID: selectedTripID)]
                )
                if !fresh.isEmpty {
                    announceRouteUpdate(newDangers: fresh, plan: plan)
                }
            }
            plannedDangerIDs = Set(dangers.map(\.id))
            withAnimation {
                routePlan = plan
                routeErrorMessage = nil
            }
            if isFirstPlan {
                let rect = plan.recommended.polyline.boundingMapRect
                let padding = max(rect.size.width, rect.size.height) * 0.35
                withAnimation(.easeInOut(duration: 0.6)) {
                    cameraPosition = .rect(rect.insetBy(dx: -padding, dy: -padding * 1.6))
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            routeErrorMessage = String(localized: "Couldn't find a walking route there.")
        }
    }

    /// Tells the user about new dangers on their route: a banner in the app, and a notification
    /// when the app is in the background (the phone is in their pocket).
    private func announceRouteUpdate(newDangers: [RouteDanger], plan: SafeRoutePlan) {
        let names = newDangers.map(\.title).joined(separator: ", ")
        let followed = routeMode == .transit
            ? plan.transitTrips.first { $0.id == selectedTripID }
            : nil
        let passedIDs = Set((followed?.dangersPassed ?? plan.recommended.dangersPassed).map(\.id))
        let isRerouted = !newDangers.contains { passedIDs.contains($0.id) }
        let arrival = followed?.trip.arrival ?? .now.addingTimeInterval(plan.recommended.travelTime)
        let minutes = max(1, Int((arrival.timeIntervalSinceNow / 60).rounded(.up)))

        let update = isRerouted
            ? RouteUpdate(
                title: String(localized: "Rerouted around a new danger"),
                message: String(localized: "\(names). New route: \(minutes) min."),
                isRerouted: true
            )
            : RouteUpdate(
                title: String(localized: "New danger on your route"),
                message: String(localized: "\(names). No safer way found, stay alert."),
                isRerouted: false
            )

        // The route still changes; the user only chose not to be told
        guard routeAlertsEnabled else { return }
        withAnimation {
            routeUpdate = update
        }
        UINotificationFeedbackGenerator().notificationOccurred(isRerouted ? .success : .warning)
        if scenePhase != .active {
            NotificationService.shared.scheduleRouteUpdateNotification(
                title: update.title,
                body: update.message,
                id: newDangers.map(\.id).sorted().joined(separator: "+")
            )
        }
    }

    /// While a route is active: keep location (and with it these checks) running in the background,
    /// and fetch new police events regularly so dangers that appear mid-walk are noticed.
    /// SL alerts are already refreshed every 90 s by `refreshTransitAlerts`.
    private func watchActiveRoute() async {
        let isActive = routeDestination != nil
        locationManager.setBackgroundTracking(isActive)
        if !isActive {
            routeUpdate = nil
            plannedDangerIDs = []
        }
        guard isActive else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(120))
            guard !Task.isCancelled else { return }
            if showPoliceReports {
                await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: transitReferenceLocation)
            }
            // Fresh real-time departures, and a route that starts from where the user is now
            routeRefreshTick += 1
        }
    }

    /// Resolves the nearest stop for each chosen transit type, then keeps their departures fresh every minute.
    private func refreshTransitStops() async {
        guard showTransit else {
            transitStops = []
            return
        }
        isLoadingTransit = transitStops.isEmpty
        let modes = TransitMode.allCases.filter { visibleTransitModes.contains($0) }
        if let stops = try? await SLTransitService.shared.nearestStops(to: transitReferenceLocation, modes: modes) {
            transitStops = stops
        }
        isLoadingTransit = false

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            var refreshed: [TransitStop] = []
            for stop in transitStops {
                refreshed.append((try? await SLTransitService.shared.refresh(stop)) ?? stop)
            }
            transitStops = refreshed
        }
    }

    private func loadVisibleStops() async {
        guard showTransit,
              let region = visibleRegion,
              region.span.latitudeDelta <= Self.stopMarkerMaxSpan else {
            visibleStops = []
            return
        }
        if let stops = try? await SLTransitService.shared.stops(in: region, modes: visibleTransitModes) {
            visibleStops = stops
        }
    }

    private func openDepartures(for summary: TransitStopSummary) async {
        guard loadingStopID == nil else { return }
        loadingStopID = summary.id
        defer { loadingStopID = nil }
        if let stop = try? await SLTransitService.shared.stop(for: summary) {
            selectedTransitStop = stop
        }
    }

    /// Opens live departures for a subway, train, tram, bus or boat icon tapped on the base map.
    private func openDepartures(for feature: MapFeature) async {
        defer { selectedMapFeature = nil }
        guard feature.pointOfInterestCategory == .publicTransport,
              let summary = try? await SLTransitService.shared.nearestStop(to: feature.coordinate),
              let stop = try? await SLTransitService.shared.stop(for: summary) else {
            return
        }
        selectedTransitStop = stop
    }

    private func annotationView(for incident: Incident, hiddenCount: Int = 0, onTap: @escaping () -> Void) -> some View {
        IncidentAnnotationView(
            incident: incident,
            isSelected: selectedIncident?.id == incident.id
        )
        // Dangers the user marked as over stay visible but faded
        .grayscale(ignoredStore.isIgnored(incident) ? 1 : 0)
        .opacity(ignoredStore.isIgnored(incident) ? 0.4 : 1)
        .overlay(alignment: .topLeading) {
            // More dangers nearby that show when zoomed in
            if hiddenCount > 0 {
                Text("+\(hiddenCount)")
                    .font(.caption2.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.75), in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 1))
                    .accessibilityLabel(Text("\(hiddenCount) more dangers nearby"))
            }
        }
        .onTapGesture(perform: onTap)
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

            if let routeUpdate {
                RouteUpdateBanner(
                    title: routeUpdate.title,
                    message: routeUpdate.message,
                    isRerouted: routeUpdate.isRerouted
                ) {
                    withAnimation {
                        self.routeUpdate = nil
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
                .task(id: routeUpdate.id) {
                    // Clears itself so it doesn't hide the map for the rest of the walk
                    try? await Task.sleep(for: .seconds(12))
                    guard !Task.isCancelled else { return }
                    withAnimation {
                        self.routeUpdate = nil
                    }
                }
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

            HStack(alignment: .bottom, spacing: 12) {
                if let destination = routeDestination {
                    SafeRouteSummaryCard(
                        destinationName: routePlan?.destinationName ?? destination.name ?? String(localized: "Destination"),
                        originName: routeOrigin?.name,
                        travelTime: routePlan?.recommended.travelTime,
                        distance: routePlan?.recommended.distance,
                        extraTime: routeComparison.extraTime,
                        avoidedCount: routeComparison.avoided,
                        passedCount: routeComparison.passed,
                        dangerNames: routeDangerNames,
                        trip: activeTrip?.trip,
                        isLoading: isPlanningRoute && routePlan == nil,
                        errorMessage: routeErrorMessage,
                        onOpenDetails: routePlan == nil ? nil : { isPresentingRouteDetails = true }
                    ) {
                        withAnimation {
                            routeDestination = nil
                            routeOrigin = nil
                            routePlan = nil
                            selectedTripID = nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if let home = myPlaces.effectiveHome {
                    TakeMeHomeButton(temporaryHomeLabel: myPlaces.activeTemporaryHome?.place.label) {
                        routePlan = nil
                        routeOrigin = nil
                        routeDestination = home.mapItem
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 12) {
                    // Everything the map can show: police reports, safe havens, transit types, time range
                    MapLayersMenuButton(
                        showPoliceReports: $showPoliceReports,
                        showSafeHavens: $showSafeHavens,
                    showTransitAlerts: $showTransitAlerts,
                    safeHavensOpenNowOnly: $safeHavensOpenNowOnly,
                        visibleTransitModes: visibleTransitModesBinding,
                        timeFilter: $timeFilter,
                        isSyncingPolice: isSyncingPoliceEvents,
                        isLoadingTransit: isLoadingTransit
                    ) {
                        Task {
                            isSyncingPoliceEvents = true
                            let reference = locationManager.userLocation ?? CLLocation(latitude: 59.3326, longitude: 18.0649)
                            await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: reference, force: true)
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            isSyncingPoliceEvents = false
                        }
                    }

                    // Fastest walking route that avoids recent dangers
                    SafeRouteButton(isActive: routeDestination != nil) {
                        isPresentingRouteSearch = true
                    }

                    // Look up departures at any SL stop
                    TransitSearchButton {
                        isPresentingStopSearch = true
                    }

                    // Call a taxi
                    TaxiCallButton {
                        isPresentingTaxiLauncher = true
                    }

                    // Safety & security buttons, closest to the thumb
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

                    ReportDangerButton {
                        isPresentingReportSheet = true
                    }
                }
            }
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
