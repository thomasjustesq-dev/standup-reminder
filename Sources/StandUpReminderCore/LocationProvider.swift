import CoreLocation
import Foundation

/// One-shot, kilometer-accuracy location for weather. If the user declines
/// (or before the first fix arrives), callers fall back to
/// `WeatherService.approxCoordinates(for:)`.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    private let manager = CLLocationManager()
    private(set) var lastCoordinate: CLLocationCoordinate2D?

    private var cacheURL: URL {
        Paths.appSupport.appendingPathComponent("last-location.json")
    }

    private struct CachedFix: Codable { var latitude: Double; var longitude: Double }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        // A fresh fix arrives asynchronously, so the first fetch of every
        // launch used to fall back to the timezone city table (Chicago for
        // all of US Central). Reuse the previous session's fix immediately.
        if let data = try? Data(contentsOf: cacheURL),
           let fix = try? JSONDecoder().decode(CachedFix.self, from: data) {
            lastCoordinate = CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude)
        }
    }

    /// Request authorization if undetermined, and a fresh fix if allowed.
    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastCoordinate = locations.last?.coordinate
        if let coord = lastCoordinate,
           let data = try? JSONEncoder().encode(CachedFix(latitude: coord.latitude, longitude: coord.longitude)) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        AppLog.write("Location fix failed: \(error.localizedDescription)")
    }
}
