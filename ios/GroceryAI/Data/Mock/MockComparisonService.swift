import Foundation

struct MockComparisonService: ComparisonServicing {
    func compare(
        items: [ProductRequest],
        postalCode: String
    ) async throws -> ComparisonPlan {
        guard !items.isEmpty else { throw ComparisonServiceError.emptyDraft }
        guard postalCode.range(of: #"^\d{5}$"#, options: .regularExpression) != nil else {
            throw ComparisonServiceError.invalidPostalCode
        }

        var allocations: [String: [StorePlanItem]] = [:]
        var unmatchedItems: [UnmatchedItem] = []

        for item in items {
            guard let offer = offer(for: item) else {
                unmatchedItems.append(
                    UnmatchedItem(
                        requestedItem: item,
                        reason: "No encontramos una presentación comparable en los datos disponibles."
                    )
                )
                continue
            }
            allocations[offer.retailer, default: []].append(offer.line)
        }

        let preferredRetailerOrder = ["Súper Centro", "Mercado Norte"]
        let stores = preferredRetailerOrder.compactMap { retailer -> StorePlan? in
            guard let lines = allocations[retailer], !lines.isEmpty else { return nil }
            return StorePlan(
                retailer: retailer,
                subtotalCents: lines.reduce(0) { $0 + $1.lineTotalCents },
                items: lines
            )
        }
        let total = stores.reduce(0) { $0 + $1.subtotalCents }

        return ComparisonPlan(
            totalPriceCents: total,
            estimatedSavingsCents: stores.count > 1 ? max(450, Int(Double(total) * 0.08)) : nil,
            stores: stores,
            unmatchedItems: unmatchedItems
        )
    }

    private func offer(for request: ProductRequest) -> MockOffer? {
        let normalizedName = request.name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
            .lowercased()

        guard let template = offerTemplates.first(where: { template in
            template.aliases.contains { normalizedName.contains($0) }
        }) else {
            return nil
        }

        let requestedBaseQuantity: Double? = if request.unit == .piece || request.unit == .package {
            request.quantity * template.packageQuantity
        } else {
            convertedQuantity(
                request.quantity,
                unit: request.unit,
                to: template.packageUnit
            )
        }
        guard let requestedBaseQuantity else { return nil }

        let packageCount = max(1, Int(ceil(requestedBaseQuantity / template.packageQuantity)))
        let lineTotal = template.priceCents * packageCount
        let unitPrice = unitPricePer100(
            priceCents: template.priceCents,
            packageQuantity: template.packageQuantity,
            packageUnit: template.packageUnit
        )

        return MockOffer(
            retailer: template.retailer,
            line: StorePlanItem(
                clientItemID: request.id,
                listingID: template.listingID,
                productName: template.productName,
                brand: "Marca ejemplo",
                requestedQuantity: request.quantity,
                requestedUnit: request.unit,
                packageQuantity: template.packageQuantity,
                packageUnit: template.packageUnit,
                packageCount: packageCount,
                priceCents: template.priceCents,
                regularPriceCents: template.regularPriceCents,
                lineTotalCents: lineTotal,
                unitPriceCentsPer100: unitPrice,
                productURL: URL(string: "https://example.com/\(template.listingID)")!,
                imageURL: template.imageURL,
                checkedAt: MockFixtures.referenceDate,
                dataStatus: .demo,
                matchType: template.matchType
            )
        )
    }

    private func convertedQuantity(
        _ quantity: Double,
        unit: ProductUnit,
        to targetUnit: ProductUnit
    ) -> Double? {
        if unit == targetUnit { return quantity }
        return switch (unit, targetUnit) {
        case (.kilogram, .gram): quantity * 1_000
        case (.gram, .kilogram): quantity / 1_000
        case (.liter, .milliliter): quantity * 1_000
        case (.milliliter, .liter): quantity / 1_000
        case (.dozen, .piece): quantity * 12
        case (.piece, .dozen): quantity / 12
        default: nil
        }
    }

    private func unitPricePer100(
        priceCents: Int,
        packageQuantity: Double,
        packageUnit: ProductUnit
    ) -> Int? {
        let quantityInSmallestUnit: Double
        switch packageUnit {
        case .kilogram, .liter:
            quantityInSmallestUnit = packageQuantity * 1_000
        case .gram, .milliliter:
            quantityInSmallestUnit = packageQuantity
        case .piece, .package, .dozen:
            return nil
        }
        return Int((Double(priceCents) / quantityInSmallestUnit * 100).rounded())
    }
}

private struct MockOffer: Sendable {
    let retailer: String
    let line: StorePlanItem
}

private struct MockOfferTemplate: Sendable {
    let aliases: [String]
    let retailer: String
    let listingID: String
    let productName: String
    let packageQuantity: Double
    let packageUnit: ProductUnit
    let priceCents: Int
    let regularPriceCents: Int?
    let matchType: MatchType

    var imageURL: URL? {
        switch listingID {
        case "super-centro-leche-1l":
            URL(string: "https://images.unsplash.com/photo-1563636619-e9143da7973b?auto=format&fit=crop&w=240&q=80")
        case "super-centro-arroz-1kg":
            URL(string: "https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=240&q=80")
        case "mercado-norte-huevos-12":
            URL(string: "https://images.unsplash.com/photo-1506976785307-8732e854ad03?auto=format&fit=crop&w=240&q=80")
        default:
            nil
        }
    }
}

private let offerTemplates: [MockOfferTemplate] = [
    MockOfferTemplate(aliases: ["leche"], retailer: "Súper Centro", listingID: "super-centro-leche-1l", productName: "Leche entera 1 L", packageQuantity: 1, packageUnit: .liter, priceCents: 3_995, regularPriceCents: 4_495, matchType: .exact),
    MockOfferTemplate(aliases: ["huevo"], retailer: "Mercado Norte", listingID: "mercado-norte-huevos-12", productName: "Huevo blanco 12 piezas", packageQuantity: 12, packageUnit: .piece, priceCents: 7_190, regularPriceCents: 8_320, matchType: .similar),
    MockOfferTemplate(aliases: ["arroz"], retailer: "Súper Centro", listingID: "super-centro-arroz-1kg", productName: "Arroz extra 1 kg", packageQuantity: 1, packageUnit: .kilogram, priceCents: 4_890, regularPriceCents: 5_290, matchType: .exact),
    MockOfferTemplate(aliases: ["pollo", "pechuga"], retailer: "Mercado Norte", listingID: "mercado-norte-pollo-1kg", productName: "Pechuga de pollo 1 kg", packageQuantity: 1, packageUnit: .kilogram, priceCents: 14_990, regularPriceCents: 16_490, matchType: .exact),
    MockOfferTemplate(aliases: ["manzana"], retailer: "Súper Centro", listingID: "super-centro-manzana-1kg", productName: "Manzana Gala 1 kg", packageQuantity: 1, packageUnit: .kilogram, priceCents: 5_490, regularPriceCents: nil, matchType: .similar),
    MockOfferTemplate(aliases: ["papel de baño", "papel higienico"], retailer: "Mercado Norte", listingID: "mercado-norte-papel-12", productName: "Papel de baño 12 rollos", packageQuantity: 1, packageUnit: .package, priceCents: 12_990, regularPriceCents: 14_990, matchType: .exact),
    MockOfferTemplate(aliases: ["aceite"], retailer: "Súper Centro", listingID: "super-centro-aceite-1l", productName: "Aceite vegetal 1 L", packageQuantity: 1, packageUnit: .liter, priceCents: 5_690, regularPriceCents: 6_190, matchType: .similar),
    MockOfferTemplate(aliases: ["tortilla"], retailer: "Mercado Norte", listingID: "mercado-norte-tortilla-1kg", productName: "Tortilla de maíz 1 kg", packageQuantity: 1, packageUnit: .kilogram, priceCents: 2_450, regularPriceCents: nil, matchType: .exact),
    MockOfferTemplate(aliases: ["cafe"], retailer: "Súper Centro", listingID: "super-centro-cafe-500g", productName: "Café molido 500 g", packageQuantity: 500, packageUnit: .gram, priceCents: 11_990, regularPriceCents: 13_490, matchType: .similar),
    MockOfferTemplate(aliases: ["yogur", "yogurt"], retailer: "Mercado Norte", listingID: "mercado-norte-yogur-4", productName: "Yogur natural 4 piezas", packageQuantity: 4, packageUnit: .piece, priceCents: 6_250, regularPriceCents: nil, matchType: .similar)
]
