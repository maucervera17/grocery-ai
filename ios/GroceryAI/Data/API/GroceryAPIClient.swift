import Foundation

// Change this single value for a physical device or deployed backend.
enum APIConfiguration {
    static let baseURL = URL(string: "http://127.0.0.1:3000")!
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
        init(_ item: ProductRequest) {
            client_item_id = item.id; name = item.name; quantity = item.quantity
            unit = item.unit; notes = item.notes
        }
        enum CodingKeys: CodingKey { case client_item_id, name, quantity, unit, notes }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(client_item_id, forKey: .client_item_id)
            try c.encode(name, forKey: .name); try c.encode(quantity, forKey: .quantity)
            try c.encode(unit, forKey: .unit)
            if let notes { try c.encode(notes, forKey: .notes) } else { try c.encodeNil(forKey: .notes) }
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
        let retailer: String; let store_name: String?; let subtotal_cents: Int; let items: [WireLine]
        func model() throws -> StorePlan {
            let lines = try items.map { try $0.model() }
            guard subtotal_cents >= 0, lines.reduce(0, {$0 + $1.lineTotalCents}) == subtotal_cents else { throw GroceryAPIError(message:"Subtotal inconsistente.") }
            return StorePlan(retailer: retailer, storeName: store_name, subtotalCents: subtotal_cents, items: lines)
        }
    }
    private struct WireLine: Decodable {
        let client_item_id: UUID; let listing_id: String; let product_name: String; let brand: String?
        let requested_quantity: Double; let requested_unit: ProductUnit
        let package_quantity: Double; let package_unit: ProductUnit; let package_count: Int
        let price_cents: Int; let regular_price_cents: Int?; let line_total_cents: Int; let unit_price_cents_per_100: Int?
        let product_url: URL; let checked_at: String; let data_status: DataStatus; let match_type: MatchType
        func model() throws -> StorePlanItem {
            let format = ISO8601DateFormatter()
            format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = format.date(from: checked_at)
            if date == nil { format.formatOptions = [.withInternetDateTime]; date = format.date(from: checked_at) }
            guard let date, ["http","https"].contains(product_url.scheme ?? ""), price_cents >= 0, package_count > 0,
                  package_quantity > 0, requested_quantity > 0 else { throw GroceryAPIError(message:"Oferta inválida.") }
            let product = price_cents.multipliedReportingOverflow(by:package_count)
            guard !product.overflow, product.partialValue == line_total_cents else { throw GroceryAPIError(message:"Importe de producto inconsistente.") }
            return StorePlanItem(clientItemID:client_item_id, listingID:listing_id, productName:product_name, brand:brand,
                requestedQuantity:requested_quantity, requestedUnit:requested_unit, packageQuantity:package_quantity, packageUnit:package_unit,
                packageCount:package_count, priceCents:price_cents, regularPriceCents:regular_price_cents, lineTotalCents:line_total_cents,
                unitPriceCentsPer100:unit_price_cents_per_100, productURL:product_url, checkedAt:date, dataStatus:data_status, matchType:match_type)
        }
    }
    private func call(_ body: Request) async throws -> WireResponse {
        var request = URLRequest(url:baseURL.appendingPathComponent("v1/chat/search"))
        request.httpMethod = "POST"; request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField:"Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for:request)
        guard let http = response as? HTTPURLResponse else { throw GroceryAPIError(message:"Respuesta HTTP inválida.") }
        let result = try JSONDecoder().decode(WireResponse.self, from:data)
        guard (200..<300).contains(http.statusCode), result.status != .error else { throw GroceryAPIError(message:result.reply) }
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
        let r = try await call(Request(action:"compare",message:nil,items:items.map(ItemBody.init),location:postalCode.isEmpty ? nil:Location(postal_code:postalCode),preferences:Preferences(max_stores:2)))
        guard let plan = r.plan else { throw GroceryAPIError(message:r.reply) }
        var model = try plan.model(requested:items)
        model.responseStatus = r.status
        model.warnings = r.errors.map(\.message)
        return model
    }
}
