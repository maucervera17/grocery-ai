import Foundation

enum RetailerID: String, Codable, CaseIterable, Hashable, Sendable {
    case chedraui
    case bodegaAurrera = "bodega_aurrera"
    case walmart
    case unknown

    init(backendValue: String?, displayName: String) {
        if let backendValue, let value = RetailerID(rawValue: backendValue) {
            self = value
            return
        }

        let normalized = displayName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        if normalized.contains("aurrera") {
            self = .bodegaAurrera
        } else if normalized.contains("chedraui") {
            self = .chedraui
        } else if normalized.contains("walmart") {
            self = .walmart
        } else {
            self = .unknown
        }
    }
}
