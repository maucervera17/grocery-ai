import Foundation

extension GroceryAPIClient: BasketQuoting {
    private struct BasketRequest: Encodable {
        let retailer_id: String
        let postal_code: String?
    }

    private struct WireBasketItem: Decodable {
        let id: String
        let name: String
        let brand: String
        let category: ProductCategory
        let quantity: Double
        let unit: String
        let monthly_packages: Double
    }

    private struct WireBasket: Decodable { let items: [WireBasketItem] }

    private struct WireBasketLine: Decodable {
        let basket_item_id: String
        let status: String
        let price_cents: Int?
        let checked_at: String?
        let data_status: String?
    }

    private struct WireBasketQuote: Decodable {
        let retailer_id: String
        let retailer_name: String
        let data_mode: String
        let prices_checked_at: String?
        let basket: WireBasket
        let items: [WireBasketLine]
    }

    func quoteBasket(retailer: RetailerID, postalCode: String?) async throws -> BasketQuote {
        var request = URLRequest(url: baseURL.appending(path: "v1/onboarding/basket"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try APIAccess.authorize(&request)
        request.httpBody = try JSONEncoder().encode(
            BasketRequest(retailer_id: retailer.rawValue, postal_code: postalCode)
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GroceryAPIError(message: "No pudimos consultar los precios.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw GroceryAPIError(
                message: "No pudimos consultar los precios.",
                isAccessProblem: http.statusCode == 401 || http.statusCode == 403
            )
        }
        let wire = try JSONDecoder().decode(WireBasketQuote.self, from: data)
        let format = ISO8601DateFormatter()
        func date(_ value: String?) -> Date? {
            guard let value else { return nil }
            if let date = format.date(from: value) { return date }
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return fractional.date(from: value)
        }
        return BasketQuote(
            retailerID: RetailerID(rawValue: wire.retailer_id) ?? retailer,
            retailerName: wire.retailer_name,
            isDemo: wire.data_mode == "demo",
            pricesCheckedAt: date(wire.prices_checked_at),
            items: wire.basket.items.map {
                BasketItem(
                    id: $0.id,
                    name: $0.name,
                    brand: $0.brand,
                    categoryID: $0.category,
                    monthlyPackages: $0.monthly_packages,
                    soldPerKilo: $0.unit == "kg" && $0.quantity == 1 && [.produce, .meat].contains($0.category)
                )
            },
            lines: wire.items.map {
                BasketQuote.Line(
                    basketItemID: $0.basket_item_id,
                    priceCents: $0.status == "priced" ? $0.price_cents : nil,
                    checkedAt: date($0.checked_at),
                    isDemo: $0.data_status == "demo"
                )
            }
        )
    }
}
