import Foundation

enum DataStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case verified
    case stale
    case demo
}

enum MatchType: String, Codable, CaseIterable, Hashable, Sendable {
    case exact
    case similar
}

struct StorePlanItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var clientItemID: UUID
    var listingID: String
    var productName: String
    var brand: String?
    var requestedQuantity: Double
    var requestedUnit: ProductUnit
    var packageQuantity: Double
    var packageUnit: ProductUnit
    var packageCount: Int
    var priceCents: Int
    var regularPriceCents: Int?
    var lineTotalCents: Int
    var unitPriceCentsPer100: Int?
    var productURL: URL
    var checkedAt: Date
    var dataStatus: DataStatus
    var matchType: MatchType

    init(
        id: UUID = UUID(),
        clientItemID: UUID,
        listingID: String,
        productName: String,
        brand: String? = nil,
        requestedQuantity: Double,
        requestedUnit: ProductUnit,
        packageQuantity: Double,
        packageUnit: ProductUnit,
        packageCount: Int,
        priceCents: Int,
        regularPriceCents: Int? = nil,
        lineTotalCents: Int,
        unitPriceCentsPer100: Int? = nil,
        productURL: URL,
        checkedAt: Date,
        dataStatus: DataStatus,
        matchType: MatchType
    ) {
        self.id = id
        self.clientItemID = clientItemID
        self.listingID = listingID
        self.productName = productName
        self.brand = brand
        self.requestedQuantity = requestedQuantity
        self.requestedUnit = requestedUnit
        self.packageQuantity = packageQuantity
        self.packageUnit = packageUnit
        self.packageCount = packageCount
        self.priceCents = priceCents
        self.regularPriceCents = regularPriceCents
        self.lineTotalCents = lineTotalCents
        self.unitPriceCentsPer100 = unitPriceCentsPer100
        self.productURL = productURL
        self.checkedAt = checkedAt
        self.dataStatus = dataStatus
        self.matchType = matchType
    }
}

struct StorePlan: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var retailer: String
    var storeName: String?
    var subtotalCents: Int
    var items: [StorePlanItem]

    init(
        id: UUID = UUID(),
        retailer: String,
        storeName: String? = nil,
        subtotalCents: Int,
        items: [StorePlanItem]
    ) {
        self.id = id
        self.retailer = retailer
        self.storeName = storeName
        self.subtotalCents = subtotalCents
        self.items = items
    }
}

struct UnmatchedItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var requestedItem: ProductRequest
    var reason: String

    init(id: UUID = UUID(), requestedItem: ProductRequest, reason: String) {
        self.id = id
        self.requestedItem = requestedItem
        self.reason = reason
    }
}

struct ComparisonPlan: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var totalPriceCents: Int
    var estimatedSavingsCents: Int?
    var currencyCode: String
    var stores: [StorePlan]
    var unmatchedItems: [UnmatchedItem]

    init(
        id: UUID = UUID(),
        totalPriceCents: Int,
        estimatedSavingsCents: Int? = nil,
        currencyCode: String = "MXN",
        stores: [StorePlan],
        unmatchedItems: [UnmatchedItem] = []
    ) {
        self.id = id
        self.totalPriceCents = totalPriceCents
        self.estimatedSavingsCents = estimatedSavingsCents
        self.currencyCode = currencyCode
        self.stores = stores
        self.unmatchedItems = unmatchedItems
    }
}
