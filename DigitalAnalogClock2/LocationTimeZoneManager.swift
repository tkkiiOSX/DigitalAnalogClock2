import Foundation
import CoreLocation

final class LocationTimeZoneManager: NSObject, ObservableObject {
    @Published private(set) var timeZone: TimeZone?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var lastGeocodedLocation: CLLocation?
    private var lastGeocodedDate: Date?

    private let minimumUpdateInterval: TimeInterval = 15 * 60
    private let minimumDistance: CLLocationDistance = 10_000

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = minimumDistance
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = true
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            start()
        } else {
            stop()
        }
    }

    func refresh() {
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()

        case .denied, .restricted:
            break

        @unknown default:
            break
        }
    }

    private func start() {
        guard CLLocationManager.locationServicesEnabled() else {
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()

        case .denied, .restricted:
            break

        @unknown default:
            break
        }
    }

    private func stop() {
        locationManager.stopUpdatingLocation()
        geocoder.cancelGeocode()
    }

    private func shouldGeocode(location: CLLocation) -> Bool {
        guard let lastGeocodedLocation,
              let lastGeocodedDate else {
            return true
        }

        let movedDistance = location.distance(from: lastGeocodedLocation)
        let elapsedTime = Date().timeIntervalSince(lastGeocodedDate)

        return movedDistance >= minimumDistance
            || elapsedTime >= minimumUpdateInterval
    }

    private func updateTimeZone(from location: CLLocation) {
        guard shouldGeocode(location: location) else {
            return
        }

        geocoder.cancelGeocode()

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self,
                  error == nil,
                  let timeZone = placemarks?.first?.timeZone else {
                return
            }

            DispatchQueue.main.async {
                self.lastGeocodedLocation = location
                self.lastGeocodedDate = Date()

                if self.timeZone?.identifier != timeZone.identifier {
                    self.timeZone = timeZone
                }
            }
        }
    }
}

extension LocationTimeZoneManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.requestLocation()

        default:
            break
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else {
            return
        }

        updateTimeZone(from: location)
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        // GPSが一時的に取得できない場合は、
        // 次回の位置情報更新またはアプリ復帰時に再試行します。
    }
}
