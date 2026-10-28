import Foundation

enum MockFixtures {
    static let referenceDate = Date(timeIntervalSince1970: 1_782_588_800)

    static let milk = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        name: "Leche",
        quantity: 2,
        unit: .liter
    )

    static let eggs = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        name: "Huevos",
        quantity: 12,
        unit: .piece
    )

    static let rice = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
        name: "Arroz",
        quantity: 1,
        unit: .kilogram
    )

    static let chicken = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
        name: "Pechuga de pollo",
        quantity: 1,
        unit: .kilogram
    )

    static let toiletPaper = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
        name: "Papel de baño",
        quantity: 1,
        unit: .package,
        notes: "12 rollos"
    )

    static let draft = ShoppingDraft(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
        items: [milk, eggs, rice],
        createdAt: referenceDate.addingTimeInterval(-600),
        updatedAt: referenceDate
    )

    static let milkLine = StorePlanItem(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!,
        clientItemID: milk.id,
        listingID: "super-centro-leche-1l",
        productName: "Leche entera 1 L",
        brand: "Marca ejemplo",
        requestedQuantity: 2,
        requestedUnit: .liter,
        packageQuantity: 1,
        packageUnit: .liter,
        packageCount: 2,
        priceCents: 3995,
        regularPriceCents: 4495,
        lineTotalCents: 7990,
        unitPriceCentsPer100: 399,
        productURL: URL(string: "https://example.com/leche-demo")!,
        checkedAt: referenceDate,
        dataStatus: .demo,
        matchType: .exact
    )

    static let riceLine = StorePlanItem(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!,
        clientItemID: rice.id,
        listingID: "super-centro-arroz-1kg",
        productName: "Arroz extra 1 kg",
        brand: "Marca ejemplo",
        requestedQuantity: 1,
        requestedUnit: .kilogram,
        packageQuantity: 1,
        packageUnit: .kilogram,
        packageCount: 1,
        priceCents: 4890,
        regularPriceCents: 5290,
        lineTotalCents: 4890,
        unitPriceCentsPer100: 489,
        productURL: URL(string: "https://example.com/arroz-demo")!,
        checkedAt: referenceDate,
        dataStatus: .demo,
        matchType: .exact
    )

    static let eggsLine = StorePlanItem(
        id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
        clientItemID: eggs.id,
        listingID: "mercado-norte-huevos-12",
        productName: "Huevo blanco 12 piezas",
        brand: "Marca ejemplo",
        requestedQuantity: 12,
        requestedUnit: .piece,
        packageQuantity: 12,
        packageUnit: .piece,
        packageCount: 1,
        priceCents: 7190,
        regularPriceCents: 8320,
        lineTotalCents: 7190,
        productURL: URL(string: "https://example.com/huevos-demo")!,
        checkedAt: referenceDate,
        dataStatus: .demo,
        matchType: .similar
    )

    static let comparisonPlan: ComparisonPlan = {
        let stores = [
            StorePlan(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                retailer: "Súper Centro",
                subtotalCents: 12_880,
                items: [milkLine, riceLine]
            ),
            StorePlan(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
                retailer: "Mercado Norte",
                subtotalCents: 7_190,
                items: [eggsLine]
            )
        ]
        return ComparisonPlan(
            totalPriceCents: 20_070,
            estimatedSavingsCents: 2_120,
            stores: stores
        )
    }()

    static let completedOrder = CompletedOrder(
        id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!,
        completedAt: referenceDate,
        requestedItems: draft.items,
        plan: comparisonPlan
    )

    static let previousOrders: [CompletedOrder] = [
        completedOrder,
        CompletedOrder(
            id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
            completedAt: referenceDate.addingTimeInterval(-1_209_600),
            requestedItems: [chicken, toiletPaper],
            stores: comparisonPlan.stores,
            totalPriceCents: 15_480,
            estimatedSavingsCents: 1_180
        )
    ]

    static let welcomeMessages: [ChatMessage] = [
        ChatMessage(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
            role: .agent,
            text: "Escribe los productos que necesitas. Puedes incluir cantidades y unidades.",
            createdAt: referenceDate
        )
    ]
}
