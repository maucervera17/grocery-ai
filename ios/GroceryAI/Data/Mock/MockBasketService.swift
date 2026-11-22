import Foundation

struct MockBasketService: BasketQuoting {
    var delay: Duration = .milliseconds(200)
    var failingRetailers: Set<RetailerID> = []

    static let items: [BasketItem] = [
        BasketItem(id: "huevo", name: "Huevo blanco Bachoco 18 piezas", brand: "Bachoco", categoryID: .eggs, monthlyPackages: 3),
        BasketItem(id: "leche", name: "Leche entera Lala 1 L", brand: "Lala", categoryID: .dairy, monthlyPackages: 16),
        BasketItem(id: "arroz", name: "Arroz súper extra Verde Valle 1 kg", brand: "Verde Valle", categoryID: .pantry, monthlyPackages: 2),
        BasketItem(id: "avena", name: "Avena Quaker 400 g", brand: "Quaker", categoryID: .pantry, monthlyPackages: 1)
    ]

    static let prices: [RetailerID: [String: Int]] = [
        .walmart: ["huevo": 7_900, "leche": 2_850, "arroz": 4_200],
        .bodegaAurrera: ["huevo": 7_400, "leche": 2_790, "arroz": 3_890, "avena": 3_290],
        .chedraui: ["huevo": 7_650, "leche": 2_650, "arroz": 3_990, "avena": 3_390]
    ]

    static let checkedAt = Date(timeIntervalSince1970: 1_793_545_200)

    func quoteBasket(retailer: RetailerID, postalCode: String?) async throws -> BasketQuote {
        try await Task.sleep(for: delay)
        if failingRetailers.contains(retailer) {
            throw GroceryAPIError(message: "No pudimos consultar los precios.")
        }
        let prices = Self.prices[retailer] ?? [:]
        return BasketQuote(
            retailerID: retailer,
            retailerName: StoreChoice.supported.first { $0.retailerID == retailer }?.title ?? "Tienda",
            isDemo: true,
            pricesCheckedAt: Self.checkedAt,
            items: Self.items,
            lines: Self.items.map {
                BasketQuote.Line(
                    basketItemID: $0.id,
                    priceCents: prices[$0.id],
                    checkedAt: prices[$0.id] == nil ? nil : Self.checkedAt,
                    isDemo: true
                )
            }
        )
    }
}
