import Foundation
import CoreLocation
import Combine
import MapKit

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
        let coordinate = location.coordinate

        Task { [coordinate] in
            let locationName = await Self.resolveLocationName(for: coordinate)
            await MainActor.run { [weak self] in
                self?.currentLocationName = locationName
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Leave the current location name unchanged; the UI can still reflect permission state.
    }

    private static func resolveLocationName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        guard let mapItem = try? await request.mapItems.first else { return nil }

        let address = mapItem.addressRepresentations
        let candidate = address?.cityWithContext
            ?? address?.fullAddress(includingRegion: true, singleLine: true)
            ?? mapItem.address?.shortAddress
            ?? mapItem.address?.fullAddress
            ?? mapItem.name

        guard let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return candidate
    }
}
