import Foundation

enum ProductUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case gram = "g"
    case kilogram = "kg"
    case milliliter = "ml"
    case liter = "L"
    case piece
    case package
    case dozen

    var displayName: String {
        switch self {
        case .gram: "g"
        case .kilogram: "kg"
        case .milliliter: "ml"
        case .liter: "L"
        case .piece: "pieza"
        case .package: "paquete"
        case .dozen: "docena"
        }
    }

    var pluralDisplayName: String {
        switch self {
        case .piece: "piezas"
        case .package: "paquetes"
        case .dozen: "docenas"
        default: displayName
        }
    }
}
