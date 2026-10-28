import CoreLocation
import Foundation
import MapKit
import Observation

@MainActor
@Observable
final class PostalCodeLocator: NSObject, @preconcurrency CLLocationManagerDelegate {
    var postalCode: String?
    var isLoading = false
    var errorMessage: String?

    private let manager = CLLocationManager()
    private var reverseGeocodingRequest: MKReverseGeocodingRequest?
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
            do {
                try await Task.sleep(for: .seconds(20))
            } catch {
                return
            }
            self?.fail("La ubicación tardó demasiado. Puedes ingresar el código postal manualmente.")
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            fail("Activa la ubicación en Ajustes o ingresa tu código postal.")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLoading else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            fail("Sin permiso de ubicación. Ingresa tu código postal manualmente.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isLoading, !resolving, let location = locations.last else { return }
        guard let request = MKReverseGeocodingRequest(location: location) else {
            fail("No pude consultar esa ubicación. Ingresa tu código postal manualmente.")
            return
        }

        resolving = true
        request.preferredLocale = Locale(identifier: "es_MX")
        reverseGeocodingRequest = request

        Task {
            do {
                let mapItems = try await request.mapItems
                guard isLoading else { return }
                guard let mapItem = mapItems.first,
                      let address = mapItem.address?.fullAddress,
                      mapItem.addressRepresentations?.region?.identifier == "MX"
                        || address.localizedCaseInsensitiveContains("México"),
                      let code = mexicanPostalCode(in: address) else {
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
        reverseGeocodingRequest?.cancel()
        reverseGeocodingRequest = nil
    }

    private func mexicanPostalCode(in address: String) -> String? {
        let pattern = #"(?<!\d)\d{5}(?!\d)"#
        guard let range = address.range(of: pattern, options: .regularExpression) else { return nil }
        return String(address[range])
    }

    private func fail(_ message: String) {
        errorMessage = message
        cancel()
    }
}
