import Combine
import CoreLocation
import Foundation

@MainActor
final class PostalCodeLocator: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var postalCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var deadline: Task<Void, Never>?
    private var resolving = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    func request() {
        guard !isLoading else { return }
        errorMessage = nil
        isLoading = true
        deadline?.cancel()
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            self?.fail("La ubicación tardó demasiado. Puedes ingresar el código postal manualmente.")
        }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: fail("Activa la ubicación en Ajustes o ingresa tu código postal.")
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLoading else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        case .denied, .restricted: fail("Sin permiso de ubicación. Ingresa tu código postal manualmente.")
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isLoading, !resolving, let location = locations.last else { return }
        resolving = true
        Task {
            do {
                let results = try await geocoder.reverseGeocodeLocation(location)
                guard isLoading else { return }
                guard let place = results.first, place.isoCountryCode == "MX", let code = place.postalCode,
                      code.range(of: "^[0-9]{5}$", options: .regularExpression) != nil else {
                    fail("No pude identificar un código postal de México. Escríbelo manualmente.")
                    return
                }
                postalCode = code
                cancel()
            } catch {
                guard isLoading else { return }
                fail("No pude obtener el código postal. Puedes ingresarlo manualmente.")
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fail("No pude obtener tu ubicación. Ingresa tu código postal manualmente.")
    }
    func cancel() {
        isLoading = false
        resolving = false
        deadline?.cancel()
        deadline = nil
        manager.stopUpdatingLocation()
        geocoder.cancelGeocode()
    }
    private func fail(_ message: String) {
        errorMessage = message
        cancel()
    }
}
