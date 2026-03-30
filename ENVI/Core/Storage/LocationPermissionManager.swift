import Foundation
import CoreLocation
import Combine

/// Manages access to the user's current location during onboarding.
final class LocationPermissionManager: NSObject, ObservableObject {

    enum AuthorizationStatus: Equatable {
        case notDetermined
        case authorizedWhenInUse
        case authorizedAlways
        case denied
        case restricted

        init(clStatus: CLAuthorizationStatus) {
            switch clStatus {
            case .notDetermined:
                self = .notDetermined
            case .authorizedWhenInUse:
                self = .authorizedWhenInUse
            case .authorizedAlways:
                self = .authorizedAlways
            case .denied:
                self = .denied
            case .restricted:
                self = .restricted
            @unknown default:
                self = .denied
            }
        }

        var isAuthorized: Bool {
            self == .authorizedWhenInUse || self == .authorizedAlways
        }
    }

    @Published private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published private(set) var currentLocationName: String?

    static let shared = LocationPermissionManager()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = AuthorizationStatus(clStatus: locationManager.authorizationStatus)
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestCurrentLocation() {
        guard authorizationStatus.isAuthorized else { return }
        locationManager.requestLocation()
    }
}

extension LocationPermissionManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = AuthorizationStatus(clStatus: manager.authorizationStatus)
        if authorizationStatus.isAuthorized {
            requestCurrentLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let placemark = placemarks?.first
            let locality = placemark?.locality
            let administrativeArea = placemark?.administrativeArea
            let country = placemark?.country

            self.currentLocationName = [locality, administrativeArea, country]
                .compactMap { value in
                    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                        return nil
                    }
                    return trimmed
                }
                .joined(separator: ", ")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Leave the current location name unchanged; the UI can still reflect permission state.
    }
}
