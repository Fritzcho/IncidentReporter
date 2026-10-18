import Foundation
import CoreLocation
import Observation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let clManager = CLLocationManager()

    var userLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var approachingIncident: Incident?
    var alertedIncidentIDs: Set<UUID> = []

    /// Distance in meters under which a proximity alert triggers
    var proximityThresholdMeters: CLLocationDistance = 500.0

    private var isAuthorized: Bool {
        #if os(visionOS)
        authorizationStatus == .authorizedWhenInUse
        #else
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #endif
    }

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        clManager.distanceFilter = 10 // meters
        authorizationStatus = clManager.authorizationStatus

        if isAuthorized {
            clManager.startUpdatingLocation()
        }
    }

    func requestLocationAuthorization() {
        if clManager.authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            clManager.startUpdatingLocation()
        }
    }

    func startUpdatingLocation() {
        clManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        clManager.stopUpdatingLocation()
    }

    func dismissApproachingIncident() {
        approachingIncident = nil
    }

    // MARK: - Proximity Alert Evaluation
    func checkProximity(to incidents: [Incident]) {
        guard let userLocation else { return }

        // Find the nearest incident
        var nearestCandidate: (incident: Incident, distance: CLLocationDistance)?

        for incident in incidents {
            let incidentLocation = CLLocation(
                latitude: incident.latitude,
                longitude: incident.longitude
            )
            let distance = userLocation.distance(from: incidentLocation)

            if distance <= proximityThresholdMeters {
                if let currentNearest = nearestCandidate {
                    if distance < currentNearest.distance {
                        nearestCandidate = (incident, distance)
                    }
                } else {
                    nearestCandidate = (incident, distance)
                }
            }
        }

        if let nearest = nearestCandidate {
            if !alertedIncidentIDs.contains(nearest.incident.id) {
                alertedIncidentIDs.insert(nearest.incident.id)
                approachingIncident = nearest.incident

                NotificationService.shared.scheduleProximityNotification(
                    for: nearest.incident,
                    distance: nearest.distance
                )
            }
        } else {
            // Cleared distance from previously approached incident
            if approachingIncident != nil {
                approachingIncident = nil
            }
        }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        userLocation = latest
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // kCLErrorDomain Code 0 is common on Simulator when location simulation is off
        print("Location manager error: \(error.localizedDescription)")
    }
}
