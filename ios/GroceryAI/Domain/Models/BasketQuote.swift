import Foundation

struct ShoppingProfile: Codable, Hashable, Sendable {
    var householdSize: String?
    var shoppingFrequency: String?
    var usualStore: String?
    var comparisonStores: [String] = []
    var postalCode: String?

    var isEmpty: Bool {
        householdSize == nil && shoppingFrequency == nil && usualStore == nil
            && comparisonStores.isEmpty && postalCode == nil
    }
}

struct BasketItem: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let brand: String
    let categoryID: ProductCategory
    let monthlyPackages: Double
    var soldPerKilo = false
}

struct BasketQuote: Hashable, Sendable {
    struct Line: Hashable, Sendable {
        let basketItemID: String
        let priceCents: Int?
        let checkedAt: Date?
        let isDemo: Bool
    }

    let retailerID: RetailerID
    let retailerName: String
    let isDemo: Bool
    let pricesCheckedAt: Date?
    let items: [BasketItem]
    let lines: [Line]

    func line(for itemID: String) -> Line? {
        lines.first { $0.basketItemID == itemID }
    }
}

protocol BasketQuoting: Sendable {
    func quoteBasket(retailer: RetailerID, postalCode: String?) async throws -> BasketQuote
}
