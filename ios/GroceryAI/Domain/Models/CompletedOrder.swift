import Foundation

struct CompletedOrder: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var completedAt: Date
    var requestedItems: [ProductRequest]
    var stores: [StorePlan]
    var totalPriceCents: Int
    var estimatedSavingsCents: Int?
    var currencyCode: String

    init(
        id: UUID = UUID(),
        completedAt: Date = .now,
        requestedItems: [ProductRequest] = [],
        stores: [StorePlan],
        totalPriceCents: Int,
        estimatedSavingsCents: Int? = nil,
        currencyCode: String = "MXN"
    ) {
        self.id = id
        self.completedAt = completedAt
        self.requestedItems = requestedItems
        self.stores = stores
        self.totalPriceCents = totalPriceCents
        self.estimatedSavingsCents = estimatedSavingsCents
        self.currencyCode = currencyCode
    }

    init(
        id: UUID = UUID(),
        completedAt: Date = .now,
        requestedItems: [ProductRequest],
        plan: ComparisonPlan
    ) {
        self.init(
            id: id,
            completedAt: completedAt,
            requestedItems: requestedItems,
            stores: plan.stores,
            totalPriceCents: plan.totalPriceCents,
            estimatedSavingsCents: plan.estimatedSavingsCents,
            currencyCode: plan.currencyCode
        )
    }
}

// Product discoveries and purchases are separate from saved comparison plans.
struct PriceListing: Codable, Hashable, Sendable {
    var source: String
    var retailer: String
    var productName: String
    var quantity: Double?
    var unit: String?
    var priceCents: Int
    var productUrl: String
    var imageUrl: String?
    var checkedAt: String
}
struct PriceOffer: Codable, Hashable, Identifiable, Sendable {
    var listing: PriceListing
    var unit_price_cents_per_100: Int
    var basis: String
    var id: String { listing.productUrl }
}
struct ProductPriceComparison: Codable, Sendable {
    var query: String
    var scope: String
    var data_mode: String
    var requested_postal_code: String?
    var offers: [PriceOffer]
}
struct SelectedProduct: Codable, Identifiable, Sendable {
    var id = UUID()
    var listing: PriceListing
    var packages: Int
    var usualPriceCents: Int?
    var totalCents: Int { listing.priceCents * packages }
    var referenceCents: Int? { usualPriceCents.map { $0 * packages } }
}
struct SavingsPurchase: Codable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var products: [SelectedProduct]
    var paidCents: Int
    var referenceCents: Int?
    var differenceCents: Int? { referenceCents.map { $0 - paidCents } }
}
struct SavingsLedger: Codable, Sendable {
    var savedProducts: [SavedDiscovery]?
    var basketID = UUID()
    var products: [SelectedProduct] = []
    var purchases: [SavingsPurchase] = []
    var estimatedTotal: Int { products.reduce(0) { $0 + $1.totalCents } }
    var referenceTotal: Int? {
        guard !products.isEmpty, products.allSatisfy({ $0.usualPriceCents != nil }) else { return nil }
        return products.reduce(0) { $0 + ($1.referenceCents ?? 0) }
    }
    var estimatedDifference: Int? { referenceTotal.map { $0 - estimatedTotal } }
    var recordedDifference: Int { purchases.compactMap(\.differenceCents).reduce(0, +) }
    var referencedPurchases: Int { purchases.filter { $0.referenceCents != nil }.count }
    mutating func confirm(paidCents: Int) {
        guard !products.isEmpty, paidCents >= 0, paidCents <= 100_000_000,
              !purchases.contains(where: { $0.id == basketID }) else { return }
        purchases.insert(SavingsPurchase(id:basketID,date:.now,products:products,paidCents:paidCents,referenceCents:referenceTotal),at:0)
        products = []; basketID = UUID()
    }
    static func cents(_ text: String) -> Int? {
        let value = text.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:",",with:".")
        guard value.range(of:#"^\d{1,7}(\.\d{1,2})?$"#,options:.regularExpression) != nil,
              let amount = Decimal(string:value,locale:Locale(identifier:"en_US_POSIX")), amount <= 1_000_000 else { return nil }
        return NSDecimalNumber(decimal:amount * 100).intValue
    }
}

struct SavedPriceObservation: Codable, Sendable {
    var priceCents: Int
    var checkedAt: String
    var scope: String
    var postalCode: String?
}
struct SavedDiscovery: Codable, Identifiable, Sendable {
    var id: String { listing.productUrl }
    var listing: PriceListing
    var query: String
    var observations: [SavedPriceObservation]
    var changeCents: Int? {
        guard let latest = observations.last else { return nil }
        let same = observations.filter { $0.scope == latest.scope && $0.postalCode == latest.postalCode }
        guard same.count > 1 else { return nil }
        return latest.priceCents - same[same.count-2].priceCents
    }
}
