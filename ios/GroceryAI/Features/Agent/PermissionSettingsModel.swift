import AVFAudio
import CoreLocation
import Observation

@MainActor
@Observable
final class PermissionSettingsModel: NSObject, @preconcurrency CLLocationManagerDelegate {
    private(set) var locationStatus: CLAuthorizationStatus
    private(set) var microphoneStatus = AVAudioApplication.shared.recordPermission

    private let locationManager = CLLocationManager()

    override init() {
        locationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
    }

    func refresh() {
        locationStatus = locationManager.authorizationStatus
        microphoneStatus = AVAudioApplication.shared.recordPermission
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestMicrophone() {
        AVAudioApplication.requestRecordPermission { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationStatus = manager.authorizationStatus
    }
}
