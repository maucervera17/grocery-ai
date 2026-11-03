import Foundation
import Testing
@testable import GroceryAI

@MainActor
struct PlaceholderSubscriptionServiceTests {
    @Test
    func purchaseSetsProAndPersistsAcrossInstances() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = PlaceholderSubscriptionService(defaults: defaults)
        #expect(!service.isPro)

        try await service.purchase(.annual)

        #expect(service.isPro)
        #expect(PlaceholderSubscriptionService(defaults: defaults).isPro)
        let restored = try await service.restore()
        #expect(restored)
    }

    @Test
    func resetForDebugClearsPro() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = PlaceholderSubscriptionService(defaults: defaults)
        try await service.purchase(.monthly)

        service.resetForDebug()

        #expect(!service.isPro)
        #expect(!PlaceholderSubscriptionService(defaults: defaults).isPro)
        let restored = try await service.restore()
        #expect(!restored)
    }

    @Test
    func plansOfferAnnualWithTrialAndMonthlyWithout() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let plans = PlaceholderSubscriptionService(defaults: defaults).plans

        #expect(plans.map(\.id) == [.annual, .monthly])
        #expect(plans[0].priceCents == 200_000)
        #expect(plans[0].trialDays == 7)
        #expect(plans[1].priceCents == 20_000)
        #expect(plans[1].trialDays == nil)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "PlaceholderSubscriptionServiceTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suiteName)!, suiteName)
    }
}
