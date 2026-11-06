import CoreLocation
import MapKit
import Observation

struct NearbyStore: Identifiable, Hashable, Sendable {
    let id: String
    let store: StoreChoice
    let name: String
    let latitude: Double
    let longitude: Double
    let distance: CLLocationDistance

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Finds real Walmart, Bodega Aurrera and Chedraui branches around a postal code.
/// Uses only the postal code (no location permission). Prices stay online prices;
/// this is context, not a claim that a branch has the quoted price.
@MainActor
@Observable
final class NearbyStoresFinder {
    enum State: Equatable {
        case idle
        case loading
        case loaded(latitude: Double, longitude: Double, stores: [NearbyStore])
        case failed
    }

    nonisolated static let searchRadius: CLLocationDistance = 4_000

    private(set) var state: State = .idle
    private var task: Task<Void, Never>?

    func find(postalCode: String) {
        task?.cancel()
        state = .loading
        task = Task { [weak self] in
            let result = await Self.search(postalCode: postalCode)
            guard !Task.isCancelled else { return }
            self?.state = result
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        state = .idle
    }

    /// Walmart Express (ex Superama) and Sam's Club are excluded: different assortment
    /// and prices than the Walmart we quote. Every Bodega Aurrera format (Express,
    /// Mi Bodega) and Chedraui Selecto are the same banner, so they count.
    nonisolated static func store(forPlaceName name: String) -> StoreChoice? {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_MX"))
        if folded.contains("sam's") || folded.contains("sams club") { return nil }
        if folded.contains("bodega aurrera") { return .bodegaAurrera }
        if folded.contains("walmart") { return folded.contains("express") ? nil : .walmart }
        if folded.contains("chedraui") { return .chedraui }
        return nil
    }

    nonisolated static func summary(for stores: [NearbyStore]) -> String {
        guard !stores.isEmpty else {
            return "No encontramos Walmart, Bodega Aurrera ni Chedraui a unos 4 km de tu CP. Igual comparamos sus precios en línea."
        }
        let parts = stores.map { "\($0.store.title) a \(distanceText($0.distance))" }
        let list = parts.count > 1
            ? parts.dropLast().joined(separator: ", ") + " y " + (parts.last ?? "")
            : parts.joined()
        let noun = stores.count == 1 ? "sucursal" : "sucursales"
        return "\(stores.count) \(noun) cerca de tu CP: \(list)."
    }

    nonisolated static func distanceText(_ meters: CLLocationDistance) -> String {
        if meters < 1_000 { return "\(Int((meters / 100).rounded()) * 100) m" }
        return String(format: "%.1f km", meters / 1_000)
    }

    nonisolated private static func search(postalCode: String) async -> State {
        guard let request = MKGeocodingRequest(addressString: "\(postalCode), México") else { return .failed }
        request.preferredLocale = Locale(identifier: "es_MX")
        let items = try? await request.mapItems
        guard let item = items?.first,
              item.address?.fullAddress.contains(postalCode) == true else { return .failed }

        let center = item.location
        let region = MKCoordinateRegion(
            center: center.coordinate,
            latitudinalMeters: searchRadius * 2,
            longitudinalMeters: searchRadius * 2
        )
        let stores = await withTaskGroup(of: [NearbyStore].self) { group in
            for store in StoreChoice.supported {
                group.addTask { await branches(of: store, in: region, around: center) }
            }
            return await group.reduce(into: []) { $0 += $1 }
        }
        return .loaded(
            latitude: center.coordinate.latitude,
            longitude: center.coordinate.longitude,
            stores: nearestPerChain(stores)
        )
    }

    /// One pin per chain keeps the map legible in dense areas (CDMX returns 30+ branches in 4 km).
    nonisolated static func nearestPerChain(_ stores: [NearbyStore]) -> [NearbyStore] {
        StoreChoice.supported
            .compactMap { chain in stores.filter { $0.store == chain }.min { $0.distance < $1.distance } }
            .sorted { $0.distance < $1.distance }
    }

    nonisolated private static func branches(
        of store: StoreChoice,
        in region: MKCoordinateRegion,
        around center: CLLocation
    ) async -> [NearbyStore] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = store.title
        request.region = region
        request.resultTypes = .pointOfInterest
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }

        var found: [NearbyStore] = []
        for item in response.mapItems {
            guard let name = item.name, Self.store(forPlaceName: name) == store else { continue }
            let distance = item.location.distance(from: center)
            guard distance <= searchRadius else { continue }
            let coordinate = item.location.coordinate
            found.append(NearbyStore(
                id: "\(store.rawValue)-\(coordinate.latitude)-\(coordinate.longitude)",
                store: store,
                name: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                distance: distance
            ))
        }
        return found
    }
}
