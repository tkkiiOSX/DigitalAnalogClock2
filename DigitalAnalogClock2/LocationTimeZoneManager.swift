import Foundation
import Combine
import CoreLocation

final class LocationTimeZoneManager: NSObject, ObservableObject {
    @Published private(set) var timeZone: TimeZone?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private var lastGeocodedLocation: CLLocation?
    private var lastGeocodedDate: Date?
    private var isEnabled = false
    private var forceNextGeocode = false

    private let minimumUpdateInterval: TimeInterval = 15 * 60
    private let minimumDistance: CLLocationDistance = 10_000

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = minimumDistance
        locationManager.activityType = .other
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled

        if enabled {
            start()
        } else {
            stop()
        }
    }

    func refresh() {
        guard isEnabled else {
            return
        }

        guard CLLocationManager.locationServicesEnabled() else {
            print("位置情報サービスが無効です")
            return
        }

        forceNextGeocode = true

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.requestLocation()

        case .denied, .restricted:
            print("位置情報の使用が許可されていません")

        @unknown default:
            break
        }
    }

    private func start() {
        guard CLLocationManager.locationServicesEnabled() else {
            print("位置情報サービスが無効です")
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            refresh()

        case .denied, .restricted:
            print("位置情報の使用が許可されていません")

        @unknown default:
            break
        }
    }

    private func stop() {
        forceNextGeocode = false
        locationManager.stopUpdatingLocation()
        geocoder.cancelGeocode()
    }

    private func shouldGeocode(location: CLLocation) -> Bool {
        if forceNextGeocode {
            return true
        }

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
        guard isEnabled else {
            return
        }

        guard shouldGeocode(location: location) else {
            return
        }

        forceNextGeocode = false
        geocoder.cancelGeocode()

        print("位置情報からタイムゾーンを取得します: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else {
                return
            }

            if let error {
                print("逆ジオコードに失敗しました: \(error)")
                return
            }

            guard let timeZone = placemarks?.first?.timeZone else {
                print("現在地からタイムゾーンを取得できませんでした")
                return
            }

            DispatchQueue.main.async {
                guard self.isEnabled else {
                    return
                }

                self.lastGeocodedLocation = location
                self.lastGeocodedDate = Date()

                print("取得したタイムゾーン: \(timeZone.identifier)")

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
        guard isEnabled else {
            return
        }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            refresh()

        case .denied, .restricted:
            print("位置情報の使用が許可されていません")

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
        print("位置情報の取得に失敗しました: \(error)")
    }
}
