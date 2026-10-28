import Foundation

struct VoiceSearchToolClient: Sendable {
    var baseURL: URL = APIConfiguration.baseURL
    var session: URLSession = .shared

    func searchProduct(
        message: String,
        currentItems: [ProductRequest],
        postalCode: String
    ) async throws -> [String: JSONValue] {
        let location = postalCode.isEmpty ? nil : Location(postalCode: postalCode)
        let payload = Request(
            action: "product_prices",
            priceScope: "published",
            message: message,
            items: currentItems,
            location: location
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/chat/search"))
        request.httpMethod = "POST"
        request.timeoutInterval = 100
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try APIAccess.authorize(&request)
        request.httpBody = try JSONEncoder().encode(payload)

        VoiceDiagnostics.event("Voice product search started")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw GroceryAPIError(message: "El servidor devolvió una respuesta inválida.")
        }
        VoiceDiagnostics.event("Voice product search returned HTTP \(response.statusCode)")

        let result = try JSONDecoder().decode([String: JSONValue].self, from: data)
        guard (200..<300).contains(response.statusCode) else {
            throw GroceryAPIError(message: "No se pudo consultar el producto.")
        }
        return result
    }

    private struct Location: Encodable {
        let postalCode: String

        enum CodingKeys: String, CodingKey {
            case postalCode = "postal_code"
        }
    }

    private struct Request: Encodable {
        let action: String
        let priceScope: String
        let message: String
        let items: [ProductRequest]
        let location: Location?

        enum CodingKeys: String, CodingKey {
            case action
            case priceScope = "price_scope"
            case message
            case items
            case location
        }
    }
}
