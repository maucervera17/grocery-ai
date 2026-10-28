import Foundation

extension MockFixtures {
    static let apples = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
        name: "Manzanas",
        quantity: 1,
        unit: .kilogram,
        categoryID: .produce
    )

    static let yogurt = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
        name: "Yogur",
        quantity: 4,
        unit: .piece,
        categoryID: .dairy
    )

    static let oil = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
        name: "Aceite vegetal",
        quantity: 1,
        unit: .liter,
        categoryID: .pantry
    )

    static let tortillas = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000009")!,
        name: "Tortillas",
        quantity: 1,
        unit: .kilogram,
        categoryID: .bakery
    )

    static let coffee = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000010")!,
        name: "Café molido",
        quantity: 500,
        unit: .gram,
        categoryID: .beverages
    )

    static let pasta = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!,
        name: "Pasta",
        quantity: 2,
        unit: .package,
        categoryID: .pantry
    )

    static let cheese = ProductRequest(
        id: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!,
        name: "Queso Oaxaca",
        quantity: 400,
        unit: .gram,
        categoryID: .dairy
    )

    static let previousOrders: [CompletedOrder] = [
        completedOrder,
        householdOrder,
        pantryOrder
    ]

    private static let householdOrder = CompletedOrder(
        id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!,
        completedAt: referenceDate.addingTimeInterval(-1_209_600),
        requestedItems: [chicken, toiletPaper, apples, milk, yogurt],
        stores: [
            mockStore(
                retailer: "Chedraui",
                items: [
                    milkLine,
                    mockLine(product: apples, listingID: "chedraui-manzanas-1kg", productName: "Manzana Gala 1 kg", packageQuantity: 1, packageUnit: .kilogram, priceCents: 5_490, imageURL: nil)
                ]
            ),
            mockStore(
                retailer: "Bodega Aurrera",
                items: [
                    mockLine(product: chicken, listingID: "aurrera-pollo-1kg", productName: "Pechuga de pollo 1 kg", packageQuantity: 1, packageUnit: .kilogram, priceCents: 14_990, imageURL: nil),
                    mockLine(product: toiletPaper, listingID: "aurrera-papel-12", productName: "Papel de baño 12 rollos", packageQuantity: 1, packageUnit: .package, priceCents: 12_990, imageURL: nil),
                    mockLine(product: yogurt, listingID: "aurrera-yogur-4", productName: "Yogur natural 4 piezas", packageQuantity: 4, packageUnit: .piece, priceCents: 6_250, imageURL: nil)
                ]
            )
        ],
        totalPriceCents: 47_710,
        estimatedSavingsCents: 3_860
    )

    private static let pantryOrder = CompletedOrder(
        id: UUID(uuidString: "50000000-0000-0000-0000-000000000003")!,
        completedAt: referenceDate.addingTimeInterval(-3_024_000),
        requestedItems: [rice, eggs, oil, tortillas, coffee, pasta, cheese],
        stores: [
            mockStore(
                retailer: "Chedraui",
                items: [
                    riceLine,
                    mockLine(product: oil, listingID: "chedraui-aceite-1l", productName: "Aceite vegetal 1 L", packageQuantity: 1, packageUnit: .liter, priceCents: 5_690, imageURL: nil),
                    mockLine(product: coffee, listingID: "chedraui-cafe-500g", productName: "Café molido 500 g", packageQuantity: 500, packageUnit: .gram, priceCents: 11_990, imageURL: nil),
                    mockLine(product: pasta, listingID: "chedraui-pasta-500g", productName: "Pasta 500 g", packageQuantity: 1, packageUnit: .package, priceCents: 2_450, imageURL: "https://chedrauimx.vtexassets.com/arquivos/ids/79564020/7501079011810_00.jpg?v=639286589338800000")
                ]
            ),
            mockStore(
                retailer: "Bodega Aurrera",
                items: [
                    eggsLine,
                    mockLine(product: tortillas, listingID: "aurrera-tortillas-1kg", productName: "Tortilla de maíz 1 kg", packageQuantity: 1, packageUnit: .kilogram, priceCents: 2_450, imageURL: nil),
                    mockLine(product: cheese, listingID: "aurrera-queso-400g", productName: "Queso Oaxaca 400 g", packageQuantity: 400, packageUnit: .gram, priceCents: 7_900, imageURL: nil)
                ]
            )
        ],
        totalPriceCents: 45_010,
        estimatedSavingsCents: 4_270
    )

    private static func mockStore(retailer: String, items: [StorePlanItem]) -> StorePlan {
        StorePlan(
            retailerID: RetailerID(backendValue: nil, displayName: retailer),
            retailer: retailer,
            subtotalCents: items.reduce(0) { $0 + $1.lineTotalCents },
            items: items
        )
    }

    private static func mockLine(
        product: ProductRequest,
        listingID: String,
        productName: String,
        packageQuantity: Double,
        packageUnit: ProductUnit,
        priceCents: Int,
        imageURL: String?
    ) -> StorePlanItem {
        let packageCount = product.unit == .package
            ? Int(product.quantity)
            : max(1, Int(ceil(product.quantity / packageQuantity)))
        return StorePlanItem(
            clientItemID: product.id,
            listingID: listingID,
            productName: productName,
            brand: "Marca demo",
            categoryID: product.categoryID,
            requestedQuantity: product.quantity,
            requestedUnit: product.unit,
            packageQuantity: packageQuantity,
            packageUnit: packageUnit,
            packageCount: packageCount,
            priceCents: priceCents,
            regularPriceCents: nil,
            lineTotalCents: priceCents * packageCount,
            productURL: URL(string: "https://example.com/demo/\(listingID)")!,
            imageURL: imageURL.flatMap(URL.init(string:)),
            checkedAt: referenceDate,
            dataStatus: .demo,
            matchType: .similar
        )
    }
}
