import Combine
import CoreLocation
import Foundation

@MainActor
final class PostalCodeLocator: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published var postalCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationDescription: String?
    private var requestID = UUID()
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var deadline: Task<Void, Never>?
    private var resolving = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func request() {
        guard !isLoading else { return }
        requestID = UUID()
        errorMessage = nil
        locationDescription = nil
        postalCode = nil
        isLoading = true
        deadline?.cancel()
        let id = requestID
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            guard self?.requestID == id else { return }
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
        guard location.horizontalAccuracy >= 0, abs(location.timestamp.timeIntervalSinceNow) <= 60 else {
            fail("No recibí una ubicación reciente. Vuelve a intentarlo o escribe tu código postal.")
            return
        }
        let id = requestID
        resolving = true
        Task {
            do {
                let results = try await geocoder.reverseGeocodeLocation(location)
                guard isLoading, requestID == id else { return }
                guard let place = results.first, place.isoCountryCode == "MX", let code = place.postalCode,
                      code.range(of: "^[0-9]{5}$", options: .regularExpression) != nil else {
                    fail("No pude identificar un código postal de México. Escríbelo manualmente.")
                    return
                }
                let area = [place.subLocality, place.locality].compactMap { $0 }.joined(separator: ", ")
                let approximate = manager.accuracyAuthorization == .reducedAccuracy || location.horizontalAccuracy > 500
                locationDescription = "\(approximate ? "Ubicación aproximada" : "Ubicación actual"): \(area). Confirma que CP \(code) corresponde a tu entrega."
                postalCode = code
                cancel()
            } catch {
                guard isLoading, requestID == id else { return }
                fail("No pude obtener el código postal. Puedes ingresarlo manualmente.")
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isLoading else { return }
        fail("No pude obtener tu ubicación. Ingresa tu código postal manualmente.")
    }
    func cancel() {
        requestID = UUID()
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
