import Foundation
import Security

enum APIConfiguration {
    static let baseURL = URL(string: "https://barasu-api.onrender.com")!

    #if DEBUG
    static let seedsDemoContent = true
    #else
    static let seedsDemoContent = false
    #endif
}

enum APIAccess {
    private static let account = "barasu-api-password"
    private static let service = "com.groceryai.app"

    static func password() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func savePassword(_ value: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty else { return }
        var attributes = query
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw GroceryAPIError(message: "No se pudo guardar el acceso en el llavero.")
        }
    }

    static func authorize(_ request: inout URLRequest) throws {
        guard let password = password(), !password.isEmpty else {
            throw GroceryAPIError(message: "Configura el acceso al servidor en Ajustes para usar Barasu.")
        }
        let credentials = Data("barasu:\(password)".utf8).base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
    }
}

struct GroceryAPIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct GroceryAPIClient: AgentServicing, ComparisonServicing {
    var baseURL: URL = APIConfiguration.baseURL
    var session: URLSession = .shared

    private struct Location: Encodable { let postal_code: String }
    private struct Preferences: Encodable { let max_stores: Int }
    private struct ItemBody: Encodable {
        let client_item_id: UUID
        let name: String
        let quantity: Double
        let unit: ProductUnit
        let notes: String?
        let category_id: ProductCategory?
        init(_ item: ProductRequest) {
            client_item_id = item.id; name = item.name; quantity = item.quantity
            unit = item.unit; notes = item.notes; category_id = item.categoryID
        }
        enum CodingKeys: CodingKey { case client_item_id, name, quantity, unit, notes, category_id }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(client_item_id, forKey: .client_item_id)
            try c.encode(name, forKey: .name); try c.encode(quantity, forKey: .quantity)
            try c.encode(unit, forKey: .unit)
            if let notes { try c.encode(notes, forKey: .notes) } else { try c.encodeNil(forKey: .notes) }
            try c.encodeIfPresent(category_id, forKey: .category_id)
        }
    }
    private struct Request: Encodable {
        let action: String
        let message: String?
        let items: [ItemBody]
        let location: Location?
        let preferences: Preferences?
    }
    private struct Issue: Decodable {
        let code: String; let message: String; let client_item_id: UUID?; let retryable: Bool
        var model: AgentIssue { AgentIssue(code: code, message: message, clientItemID: client_item_id, retryable: retryable) }
    }
    private struct WireResponse: Decodable {
        let reply: String; let status: AgentOperationStatus
        let draft_items: [ProductRequest]; let plan: WirePlan?; let errors: [Issue]
    }
    private struct WirePlan: Decodable {
        let total_price_cents: Int; let estimated_savings_cents: Int?; let currency: String
        let stores: [WireStore]; let unmatched_items: [WireUnmatched]
        func model(requested: [ProductRequest]) throws -> ComparisonPlan {
            guard currency == "MXN", total_price_cents >= 0 else { throw GroceryAPIError(message: "Respuesta monetaria inválida.") }
            let groups = try stores.map { try $0.model() }
            guard groups.reduce(0, { $0 + $1.subtotalCents }) == total_price_cents else { throw GroceryAPIError(message: "Total inconsistente.") }
            let unmatched = try unmatched_items.map { item in
                guard let original = requested.first(where: { $0.id == item.client_item_id }) else { throw GroceryAPIError(message: "Producto desconocido en la respuesta.") }
                return UnmatchedItem(requestedItem: original, reason: item.reason)
            }
            return ComparisonPlan(totalPriceCents: total_price_cents, estimatedSavingsCents: estimated_savings_cents, currencyCode: currency, stores: groups, unmatchedItems: unmatched)
        }
    }
    private struct WireUnmatched: Decodable { let client_item_id: UUID; let name: String; let reason: String }
    private struct WireStore: Decodable {
        let retailer_id: String; let retailer_name: String; let store_name: String?; let subtotal_cents: Int; let items: [WireLine]
        func model() throws -> StorePlan {
            let lines = try items.map { try $0.model() }
            guard subtotal_cents >= 0, lines.reduce(0, {$0 + $1.lineTotalCents}) == subtotal_cents else { throw GroceryAPIError(message:"Subtotal inconsistente.") }
            return StorePlan(retailerID: RetailerID(backendValue: retailer_id, displayName: retailer_name), retailer: retailer_name, storeName: store_name, subtotalCents: subtotal_cents, items: lines)
        }
    }
    private struct WireLine: Decodable {
        let client_item_id: UUID; let listing_id: String; let product_name: String; let brand: String?; let category_id: ProductCategory
        let requested_quantity: Double; let requested_unit: ProductUnit
        let package_quantity: Double; let package_unit: ProductUnit; let package_count: Int
        let price_cents: Int; let regular_price_cents: Int?; let line_total_cents: Int; let unit_price_cents_per_100: Int?
        let product_url: URL; let image_url: URL?; let checked_at: String; let data_status: DataStatus; let match_type: MatchType
        func model() throws -> StorePlanItem {
            let format = ISO8601DateFormatter()
            format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = format.date(from: checked_at)
            if date == nil { format.formatOptions = [.withInternetDateTime]; date = format.date(from: checked_at) }
            guard let date, ["http","https"].contains(product_url.scheme ?? ""), price_cents >= 0, package_count > 0,
                  package_quantity > 0, requested_quantity > 0 else { throw GroceryAPIError(message:"Oferta inválida.") }
            let product = price_cents.multipliedReportingOverflow(by:package_count)
            guard !product.overflow, product.partialValue == line_total_cents else { throw GroceryAPIError(message:"Importe de producto inconsistente.") }
            return StorePlanItem(clientItemID:client_item_id, listingID:listing_id, productName:product_name, brand:brand, categoryID:category_id,
                requestedQuantity:requested_quantity, requestedUnit:requested_unit, packageQuantity:package_quantity, packageUnit:package_unit,
                packageCount:package_count, priceCents:price_cents, regularPriceCents:regular_price_cents, lineTotalCents:line_total_cents,
                unitPriceCentsPer100:unit_price_cents_per_100, productURL:product_url, imageURL:image_url,
                checkedAt:date, dataStatus:data_status, matchType:match_type)
        }
    }
    private func call(_ body: Request) async throws -> WireResponse {
        ComparisonDiagnostics.event(
            "Search request started: action=\(body.action), items=\(body.items.count), hasLocation=\(body.location != nil)"
        )
        var request = URLRequest(url:baseURL.appendingPathComponent("v1/chat/search"))
        request.httpMethod = "POST"
        request.timeoutInterval = body.action == "compare" ? .infinity : 100
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        try APIAccess.authorize(&request)
        request.httpBody = try JSONEncoder().encode(body)
        let clock = ContinuousClock()
        let startedAt = clock.now
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for:request)
        } catch {
            ComparisonDiagnostics.error(
                "Search transport failed after \(startedAt.duration(to: clock.now)): action=\(body.action), error=\(error.localizedDescription)"
            )
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            ComparisonDiagnostics.error("Search endpoint returned a non-HTTP response")
            throw GroceryAPIError(message:"Respuesta HTTP inválida.")
        }
        ComparisonDiagnostics.event(
            "Search endpoint returned HTTP \(http.statusCode), bytes=\(data.count), action=\(body.action), contentType=\(http.value(forHTTPHeaderField: "Content-Type") ?? "unknown"), cfRay=\(http.value(forHTTPHeaderField: "CF-RAY") ?? "none")"
        )
        if http.statusCode == 401 { throw GroceryAPIError(message:"Acceso incorrecto. Actualiza la contraseña en Ajustes.") }
        guard (200..<300).contains(http.statusCode) else {
            ComparisonDiagnostics.error(
                "Search origin failed: HTTP \(http.statusCode), cfErrorType=\(http.value(forHTTPHeaderField: "cf-error-type") ?? "none")"
            )
            let message = http.statusCode == 520
                ? "El servidor de precios cerró la conexión durante la comparación."
                : "El servidor de precios respondió con el código \(http.statusCode)."
            throw GroceryAPIError(message: message)
        }
        let result: WireResponse
        do {
            result = try JSONDecoder().decode(WireResponse.self, from:data)
        } catch {
            ComparisonDiagnostics.error(
                "Search response decoding failed for action=\(body.action): \(error.localizedDescription)"
            )
            throw error
        }
        guard result.status != .error else {
            let issueCodes = Set(result.errors.map(\.code)).sorted().joined(separator: ",")
            ComparisonDiagnostics.error(
                "Search request rejected: action=\(body.action), status=\(result.status.rawValue), issues=\(result.errors.count), codes=[\(issueCodes)]"
            )
            throw GroceryAPIError(message:result.reply)
        }
        let ids = result.draft_items.map(\.id)
        guard Set(ids).count == ids.count, ids.count <= 20,
              result.draft_items.allSatisfy({ !$0.name.isEmpty && $0.quantity.isFinite && $0.quantity > 0 }) else { throw GroceryAPIError(message:"Borrador inválido.") }
        return result
    }
    func updateDraft(message: String, currentItems: [ProductRequest]) async throws -> AgentResponse {
        let r = try await call(Request(action:"update_draft",message:message,items:currentItems.map(ItemBody.init),location:nil,preferences:nil))
        return AgentResponse(reply:r.reply,status:r.status,draftItems:r.draft_items,errors:r.errors.map(\.model))
    }
    func compare(items: [ProductRequest], postalCode: String) async throws -> ComparisonPlan {
        ComparisonDiagnostics.event(
            "Comparison started: items=\(items.count), postalCodeLength=\(postalCode.count)"
        )
        let r = try await call(Request(action:"compare",message:nil,items:items.map(ItemBody.init),location:postalCode.isEmpty ? nil:Location(postal_code:postalCode),preferences:Preferences(max_stores:2)))
        guard let plan = r.plan else {
            ComparisonDiagnostics.error(
                "Comparison response did not contain a plan: status=\(r.status.rawValue), issues=\(r.errors.count)"
            )
            throw GroceryAPIError(message:r.reply)
        }
        var model = try plan.model(requested:items)
        model.responseStatus = r.status
        model.warnings = r.errors.map(\.message)
        ComparisonDiagnostics.event(
            "Comparison completed: stores=\(model.stores.count), unmatched=\(model.unmatchedItems.count), status=\(r.status.rawValue)"
        )
        return model
    }
}
