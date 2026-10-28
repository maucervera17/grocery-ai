import Foundation

protocol AgentServicing: Sendable {
    func updateDraft(
        message: String,
        currentItems: [ProductRequest]
    ) async throws -> AgentResponse
}

protocol ProductPriceServicing: Sendable {
    func productPrices(
        message: String,
        items: [ProductRequest],
        postalCode: String,
        local: Bool
    ) async throws -> (String, ProductPriceComparison?)
}

enum AgentServiceError: LocalizedError, Equatable, Sendable {
    case emptyMessage
    case noProductsFound

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            "Escribe al menos un producto."
        case .noProductsFound:
            "No pude identificar productos en el mensaje."
        }
    }
}
