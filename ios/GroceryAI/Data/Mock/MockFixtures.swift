import Foundation

enum MockFixtures {
    static let referenceDate = Date(timeIntervalSince1970: 1_793_210_400)

    static let milk = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
        name: "Leche",
        quantity: 2,
        unit: .liter,
        categoryID: .dairy
    )

    static let eggs = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
        name: "Huevos",
        quantity: 12,
        unit: .piece,
        categoryID: .eggs
    )

    static let rice = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
        name: "Arroz",
        quantity: 1,
        unit: .kilogram,
        categoryID: .pantry
    )

    static let chicken = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
        name: "Pechuga de pollo",
        quantity: 1,
        unit: .kilogram,
        categoryID: .meat
    )

    static let toiletPaper = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
        name: "Papel de baño",
        quantity: 1,
        unit: .package,
        notes: "12 rollos",
        categoryID: .household
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
        categoryID: .dairy,
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
        imageURL: URL(string: "https://chedrauimx.vtexassets.com/arquivos/ids/79601313/7501295600126_00.jpg?v=639287210270370000")!,
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
        categoryID: .pantry,
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
        imageURL: URL(string: "https://chedrauimx.vtexassets.com/arquivos/ids/79565827/7502219833491_00.jpg?v=639286593324930000")!,
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
        categoryID: .eggs,
        requestedQuantity: 12,
        requestedUnit: .piece,
        packageQuantity: 12,
        packageUnit: .piece,
        packageCount: 1,
        priceCents: 7190,
        regularPriceCents: 8320,
        lineTotalCents: 7190,
        productURL: URL(string: "https://example.com/huevos-demo")!,
        imageURL: nil,
        checkedAt: referenceDate,
        dataStatus: .demo,
        matchType: .similar
    )

    static let comparisonPlan: ComparisonPlan = {
        let stores = [
            StorePlan(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!,
                retailerID: .chedraui,
                retailer: "Chedraui",
                subtotalCents: 12_880,
                items: [milkLine, riceLine]
            ),
            StorePlan(
                id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!,
                retailerID: .bodegaAurrera,
                retailer: "Bodega Aurrera",
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

    static let welcomeMessages: [ChatMessage] = [
        ChatMessage(
            id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!,
            role: .agent,
            text: "Escribe los productos que necesitas. Puedes incluir cantidades y unidades.",
            createdAt: referenceDate
        )
    ]
}
