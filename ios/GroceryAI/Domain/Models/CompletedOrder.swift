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
