import Foundation

/// Monthly cost of the onboarding basket, built only from quoted prices.
struct BasketEstimate: Equatable, Sendable {
    struct StoreTotal: Equatable, Sendable, Identifiable {
        let retailerID: RetailerID
        let name: String
        let monthlyCents: Int
        let pricedCount: Int
        let missingItemNames: [String]
        var id: RetailerID { retailerID }
    }

    struct ItemRow: Equatable, Sendable, Identifiable {
        let item: BasketItem
        let monthlyPackages: Double
        /// nil = no disponible en esta tienda.
        let prices: [RetailerID: Int?]
        var id: String { item.id }
    }

    let baseStore: StoreChoice?
    let comparisonStores: [StoreChoice]
    /// Only when the base store is supported and quoted.
    let baseMonthlyCents: Int?
    /// Comparable items bought where each is cheapest among the chosen stores.
    let chosenMonthlyCents: Int?
    let savingsMonthlyCents: Int?
    let comparableItemCount: Int
    let storeTotals: [StoreTotal]
    let rows: [ItemRow]
    let pricesCheckedAt: Date?
    let isDemo: Bool
    /// Monthly cost = per-trip cost × trips per month.
    var tripsPerMonth: Double = ShoppingFrequency.weekly.tripsPerMonth

    func perTripCents(_ monthlyCents: Int) -> Int {
        Int((Double(monthlyCents) / tripsPerMonth).rounded())
    }

    var baseIsSupported: Bool { baseStore?.isSupportedByBarasu ?? false }

    static func make(
        quotes: [BasketQuote],
        baseStore: StoreChoice?,
        comparisonStores: [StoreChoice],
        householdSize: HouseholdSize?,
        frequency: ShoppingFrequency?
    ) -> BasketEstimate? {
        guard let items = quotes.first?.items, !items.isEmpty else { return nil }
        let multiplier = (householdSize ?? .threeFour).spendMultiplier
        let quoteByID = Dictionary(quotes.map { ($0.retailerID, $0) }, uniquingKeysWith: { first, _ in first })
        let chosenIDs = comparisonStores.compactMap(\.retailerID).filter { quoteByID[$0] != nil }
        let baseID = baseStore?.retailerID.flatMap { quoteByID[$0] == nil ? nil : $0 }

        func price(_ retailer: RetailerID, _ itemID: String) -> Int? {
            quoteByID[retailer]?.line(for: itemID)?.priceCents
        }
        func cents(_ price: Int, _ packages: Double) -> Int {
            Int((Double(price) * packages).rounded())
        }

        var baseTotal = 0, chosenTotal = 0, comparable = 0
        var rows: [ItemRow] = []
        for item in items {
            let packages = item.monthlyPackages * multiplier
            var prices: [RetailerID: Int?] = [:]
            for id in Set(chosenIDs + [baseID].compactMap { $0 }) {
                prices[id] = .some(price(id, item.id))
            }
            rows.append(ItemRow(item: item, monthlyPackages: packages, prices: prices))

            guard let cheapest = chosenIDs.compactMap({ price($0, item.id) }).min() else { continue }
            if let baseID {
                guard let basePrice = price(baseID, item.id) else { continue }
                baseTotal += cents(basePrice, packages)
            }
            chosenTotal += cents(cheapest, packages)
            comparable += 1
        }

        let totals = (chosenIDs + [baseID].compactMap { $0 })
            .reduce(into: [RetailerID]()) { if !$0.contains($1) { $0.append($1) } }
            .compactMap { id -> StoreTotal? in
                guard let quote = quoteByID[id] else { return nil }
                let priced = items.filter { price(id, $0.id) != nil }
                return StoreTotal(
                    retailerID: id,
                    name: quote.retailerName,
                    monthlyCents: priced.reduce(0) { $0 + cents(price(id, $1.id)!, $1.monthlyPackages * multiplier) },
                    pricedCount: priced.count,
                    missingItemNames: items.filter { price(id, $0.id) == nil }.map(\.name)
                )
            }

        let base = baseID != nil && comparable > 0 ? baseTotal : nil
        let chosen = comparable > 0 ? chosenTotal : nil
        return BasketEstimate(
            baseStore: baseStore,
            comparisonStores: comparisonStores,
            baseMonthlyCents: base,
            chosenMonthlyCents: chosen,
            savingsMonthlyCents: base.flatMap { base in chosen.map { max(0, base - $0) } },
            comparableItemCount: comparable,
            storeTotals: totals,
            rows: rows,
            pricesCheckedAt: quotes.compactMap(\.pricesCheckedAt).max(),
            isDemo: quotes.contains { $0.isDemo },
            tripsPerMonth: (frequency ?? .weekly).tripsPerMonth
        )
    }

    /// Scales the figures to the spend the user reports, keeping the quoted ratio.
    func adjusted(toMonthlySpendCents spend: Int?) -> (base: Int?, chosen: Int?, savings: Int?) {
        guard let spend, let base = baseMonthlyCents, base > 0, let chosen = chosenMonthlyCents else {
            return (baseMonthlyCents, chosenMonthlyCents, savingsMonthlyCents)
        }
        let ratio = Double(chosen) / Double(base)
        let scaledChosen = Int((Double(spend) * ratio).rounded())
        return (spend, scaledChosen, max(0, spend - scaledChosen))
    }
}
