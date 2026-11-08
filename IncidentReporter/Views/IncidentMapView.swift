import SwiftUI
import MapKit
import SwiftData

struct IncidentMapView: View {
    @Query(sort: \Incident.timestamp, order: .reverse) private var incidents: [Incident]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var selectedTransitAlert: TransitSafetyAlert?
    @State private var transitAlerts: [TransitSafetyAlert] = []
    @State private var transitStops: [TransitStop] = []
    @State private var isLoadingTransit = false
    /// A transit icon drawn by Apple Maps that the user tapped
    @State private var selectedMapFeature: MapFeature?
    /// Visible map area, used to draw subway and commuter train stops in view when zoomed in
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

    // Safe route navigation state
    @State private var isPresentingRouteSearch = false
    @State private var routeDestination: MKMapItem?
    @State private var routeOrigin: MKMapItem?
    @State private var plannedDangerIDs: Set<String> = []
    @State private var routeUpdate: RouteUpdate?
    @State private var routeMode: RouteMode = .walk
    @State private var selectedTripID: String?
    @State private var isPresentingRouteDetails = false
    @State private var routeRefreshTick = 0
    @State private var routePlan: SafeRoutePlan?
    @State private var isPlanningRoute = false
    @State private var routeErrorMessage: String?

    @AppStorage("showPoliceReports") private var showPoliceReports = true
    @AppStorage("showSafeHavens") private var showSafeHavens = true
    @AppStorage("incidentTimeFilter") private var timeFilter: IncidentTimeFilter = .twelveHours
    @AppStorage("shakeTriggerAction") private var shakeTriggerActionRaw: String = ShakeTriggerAction.fakeCall.rawValue
    @AppStorage("proximityAlertsEnabled") private var proximityAlertsEnabled = true
    @AppStorage("proximityAlertDistance") private var proximityAlertDistance: Double = 500.0
    @AppStorage("routeCaution") private var routeCaution: RouteCaution = .balanced
    @AppStorage("preferredTravelMode") private var preferredTravelMode: PreferredTravelMode = .automatic
    @AppStorage("routeAlertsEnabled") private var routeAlertsEnabled = true

    /// Subway and commuter train stations are shown by default; bus stops and other modes are excluded
    private let visibleTransitModes: Set<TransitMode> = [.metro, .train]
    private let showTransit: Bool = true

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

    /// Incidents that trigger proximity alerts (excludes dangers the user marked as over)
    private var activeIncidents: [Incident] {
        displayedIncidents.filter { !ignoredStore.isIgnored($0) }
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

    /// Reference point for the nearest-stop search: the user's position, or Central Stockholm
    private var transitReferenceLocation: CLLocation {
        locationManager.userLocation ?? CLLocation(latitude: 59.3326, longitude: 18.0649)
    }

    /// Changes when the user moves roughly 200 m, so nearest stops are re-resolved without re-querying on every GPS fix
    private var transitSearchKey: String {
        let coordinate = transitReferenceLocation.coordinate
        return "\(Int(coordinate.latitude * 500))-\(Int(coordinate.longitude * 250))"
    }

    /// Stop markers are only drawn when the map shows roughly 3 km or less, to keep the map readable
    private static let stopMarkerMaxSpan: CLLocationDegrees = 0.03

    /// Changes when the user pans or zooms meaningfully, so stop markers reload without thrashing
    private var visibleStopsKey: String {
        guard showTransit, let region = visibleRegion else { return "hidden" }
        guard region.span.latitudeDelta <= Self.stopMarkerMaxSpan else { return "zoomed-out" }
        return "\(Int(region.center.latitude * 2000))-\(Int(region.center.longitude * 1000))-\(Int(region.span.latitudeDelta * 2000))"
    }

    /// Visible stop markers, minus stops that already have a nearest-stop pin
    private var stopMarkers: [TransitStopSummary] {
        let pinned = Set(transitStops.map(\.id))
        return visibleStops.filter { !pinned.contains($0.id) }
    }

    /// Filter to only show public transport POIs (subways, train stations) and hide restaurants, hotels, etc.
    private let transitOnlyPOIFilter = PointOfInterestCategories.including([.publicTransport])

    var body: some View {
        attachTasksAndObservers(to:
            attachSheets(to:
                ZStack {
                    mapLayer

                    overlayControls
                }
            )
        )
    }

    // MARK: - Modifiers split to maintain fast compiler type-checking
    @ViewBuilder
    private func attachSheets(to view: some View) -> some View {
        view
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
            .sheet(item: $selectedTransitStop) { stop in
                TransitStopDetailSheet(
                    stop: stop,
                    userLocation: locationManager.userLocation
                )
            }
            .sheet(item: $selectedTransitAlert) { alert in
                TransitAlertDetailSheet(
                    alert: alert,
                    userLocation: locationManager.userLocation
                )
            }
            .sheet(isPresented: $isPresentingReportSheet) {
                ReportIncidentSheet(
                    initialCoordinate: locationManager.userLocation?.coordinate
                )
            }
            .sheet(isPresented: $isPresentingRouteSearch) {
                SafeRouteSearchSheet(
                    userLocation: locationManager.userLocation,
                    origin: routeOrigin,
                    destination: routeDestination,
                    home: myPlaces.effectiveHome,
                    isTemporaryHome: myPlaces.activeTemporaryHome != nil,
                    savedPlaces: myPlaces.otherSavedPlaces
                ) { origin, destination in
                    routePlan = nil
                    routeOrigin = origin
                    routeDestination = destination
                }
            }
            .sheet(isPresented: $isPresentingRouteDetails) {
                if let plan = routePlan {
                    RouteDetailSheet(
                        plan: plan,
                        mode: $routeMode,
                        selectedTripID: $selectedTripID
                    )
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
    }

    @ViewBuilder
    private func attachTasksAndObservers(to view: some View) -> some View {
        view
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

                let reference = locationManager.userLocation ?? CLLocation(latitude: 59.3326, longitude: 18.0649)
                if showPoliceReports {
                    await PoliceAPIService.syncWithDatabase(modelContext: modelContext, referenceLocation: reference)
                }
                safeHavens = await SafeHavenService.shared.fetchHavens(around: reference.coordinate)
            }
            .task {
                await refreshTransitAlerts()
            }
            .task(id: routeKey) {
                await planRoute()
            }
            .task(id: routeDestination != nil) {
                await watchActiveRoute()
            }
            .task(id: "\(proximityAlertsEnabled)-\(proximityAlertDistance)") {
                locationManager.proximityAlertsEnabled = proximityAlertsEnabled
                locationManager.proximityThresholdMeters = proximityAlertDistance
                if !proximityAlertsEnabled {
                    locationManager.dismissApproachingIncident()
                }
            }
            .task(id: transitSearchKey) {
                await refreshTransitStops()
            }
            .task(id: visibleStopsKey) {
                await loadVisibleStops()
            }
            .onChange(of: selectedMapFeature) { _, feature in
                guard let feature else { return }
                Task { await openDepartures(for: feature) }
            }
            .onChange(of: locationManager.userLocation) { oldLoc, newLoc in
                locationManager.checkProximity(to: activeIncidents)

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

                // Safe route polylines and markers
                routeMapContent

                // Danger & incident annotations
                ForEach(displayedIncidents) { incident in
                    Annotation(incident.title, coordinate: incident.coordinate) {
                        annotationView(for: incident) {
                            handlePinTap(at: incident.coordinate, proxy: proxy) {
                                selectedIncident = incident
                            }
                        }
                    }
                }

                // SL safety alerts (police operations, track fires, station closures)
                ForEach(transitAlerts) { alert in
                    let isIgnored = ignoredStore.isIgnored(key: alert.ignoreKey)
                    Annotation(alert.header, coordinate: alert.coordinate) {
                        TransitAlertAnnotationView(
                            alert: alert,
                            isSelected: selectedTransitAlert?.id == alert.id
                        )
                        .grayscale(isIgnored ? 1 : 0)
                        .opacity(isIgnored ? 0.4 : 1)
                        .onTapGesture {
                            handlePinTap(at: alert.coordinate, proxy: proxy) {
                                selectedTransitAlert = alert
                            }
                        }
                    }
                }

                // Subway and commuter train stops in view when zoomed in; tap for details
                ForEach(stopMarkers) { stop in
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

                // Nearest subway and commuter train stop, with live departures
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
                    ForEach(safeHavens) { haven in
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

    @MapContentBuilder
    private var routeMapContent: some MapContent {
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
    }

    // MARK: - Overlapping pins

    /// Pins whose centres are closer than this on screen overlap enough to be hard to tap apart
    private static let pinOverlapDistance: CGFloat = 36
    /// Closest the overlap zoom goes (roughly 150 m across); past this, the tapped pin just opens
    private static let minimumOverlapZoomSpan: CLLocationDegrees = 0.0015

    /// Every pin currently drawn on the map
    private var pinCoordinates: [CLLocationCoordinate2D] {
        var coordinates = displayedIncidents.map(\.coordinate)
        coordinates += stopMarkers.filter { $0.primaryMode(in: visibleTransitModes) != nil }.map(\.coordinate)
        coordinates += transitAlerts.map(\.coordinate)
        if showTransit {
            coordinates += transitStops.map(\.coordinate)
        }
        if showSafeHavens {
            coordinates += safeHavens.map(\.coordinate)
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

    /// While a route is active: keep location running in the background if possible,
    /// and fetch new police events regularly so dangers that appear mid-walk are noticed.
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
            routeRefreshTick += 1
        }
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

    /// Resolves the nearest subway and commuter train stations, then keeps their departures fresh every minute.
    private func refreshTransitStops() async {
        guard showTransit else {
            transitStops = []
            return
        }
        isLoadingTransit = transitStops.isEmpty
        let modes: [TransitMode] = [.metro, .train]
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

    /// Loads the full departures sheet when a stop marker is tapped.
    private func openDepartures(for summary: TransitStopSummary) async {
        guard loadingStopID == nil else { return }
        loadingStopID = summary.id
        defer { loadingStopID = nil }
        if let stop = try? await SLTransitService.shared.stop(for: summary) {
            selectedTransitStop = stop
        }
    }

    /// Opens live departures for a subway or train icon tapped on the base map.
    private func openDepartures(for feature: MapFeature) async {
        defer { selectedMapFeature = nil }
        guard feature.pointOfInterestCategory == .publicTransport,
              let summary = try? await SLTransitService.shared.nearestStop(to: feature.coordinate),
              let stop = try? await SLTransitService.shared.stop(for: summary) else {
            return
        }
        guard stop.modes.contains(where: { visibleTransitModes.contains($0) }) else { return }
        selectedTransitStop = stop
    }

    private func annotationView(for incident: Incident, onTap: @escaping () -> Void) -> some View {
        IncidentAnnotationView(
            incident: incident,
            isSelected: selectedIncident?.id == incident.id
        )
        // Dangers the user marked as over stay visible but faded
        .grayscale(ignoredStore.isIgnored(incident) ? 1 : 0)
        .opacity(ignoredStore.isIgnored(incident) ? 0.4 : 1)
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

            if let update = routeUpdate {
                RouteUpdateBanner(
                    title: update.title,
                    message: update.message,
                    isRerouted: update.isRerouted
                ) {
                    withAnimation { routeUpdate = nil }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, 8)
            }

            Spacer()

            bottomControls
        }
    }

    @ViewBuilder
    private var bottomControls: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 12) {
                if let destination = routeDestination {
                    safeRouteSummaryCard(destination: destination)
                } else if let home = myPlaces.effectiveHome {
                    TakeMeHomeButton(temporaryHomeLabel: myPlaces.activeTemporaryHome?.place.label) {
                        routePlan = nil
                        routeOrigin = nil
                        routeDestination = home.mapItem
                    }
                    .padding(.bottom, 56)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                trailingButtonsColumn
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Big green Safe Route button centered right above the bottom menu bar
            if routeDestination == nil {
                SafeRouteButton {
                    isPresentingRouteSearch = true
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func safeRouteSummaryCard(destination: MKMapItem) -> some View {
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
    }

    @ViewBuilder
    private var trailingButtonsColumn: some View {
        VStack(alignment: .trailing, spacing: 12) {
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

            // Report danger button
            ReportDangerButton {
                isPresentingReportSheet = true
            }
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
