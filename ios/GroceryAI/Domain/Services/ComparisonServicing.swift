import Foundation

protocol ComparisonServicing: Sendable {
    func compare(
        items: [ProductRequest],
        postalCode: String
    ) async throws -> ComparisonPlan
}

enum ComparisonServiceError: LocalizedError, Equatable, Sendable {
    case emptyDraft
    case invalidPostalCode

    var errorDescription: String? {
        switch self {
        case .emptyDraft:
            "Agrega al menos un producto antes de comparar."
        case .invalidPostalCode:
            "Ingresa un código postal de cinco dígitos."
        }
    }
}
