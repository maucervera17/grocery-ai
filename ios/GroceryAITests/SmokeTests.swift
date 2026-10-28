import Foundation
import Testing
@testable import GroceryAI

struct SmokeTests {
    @Test
    func APIRequiresConfiguredURLForReleaseAndBuildsVersionedPaths() throws {
        let endpoint = try APIConfiguration.endpoint(
            "v1/chat/search",
            baseURL: URL(string: "https://api.example.com")
        )
        #expect(endpoint.absoluteString == "https://api.example.com/v1/chat/search")
        #expect(throws: GroceryAPIError.self) {
            try APIConfiguration.endpoint("v1/voice/session", baseURL: nil)
        }
    }

    @Test
    func agentParsesQuantitiesAndUnits() async throws {
        let response = try await MockAgentService().updateDraft(
            message: "2 litros de leche, 12 huevos",
            currentItems: []
        )

        #expect(response.draftItems.count == 2)
        #expect(response.draftItems[0].name == "Leche")
        #expect(response.draftItems[0].quantity == 2)
        #expect(response.draftItems[0].unit == .liter)
        #expect(response.draftItems[1].quantity == 12)
    }

    @Test
    func agentAccumulatesAnExistingProduct() async throws {
        let response = try await MockAgentService().updateDraft(
            message: "1 litro de leche",
            currentItems: [MockFixtures.milk]
        )

        #expect(response.draftItems.count == 1)
        #expect(response.draftItems[0].quantity == 3)
    }

    @Test
    func comparisonAllocatesProductsAcrossStores() async throws {
        let plan = try await MockComparisonService().compare(
            items: MockFixtures.draft.items,
            postalCode: "06700"
        )

        #expect(plan.stores.count == 2)
        #expect(plan.totalPriceCents > 0)
        #expect(plan.stores.flatMap(\.items).count == 3)
    }

    @Test
    func comparisonRejectsInvalidPostalCode() async {
        await #expect(throws: ComparisonServiceError.invalidPostalCode) {
            try await MockComparisonService().compare(
                items: MockFixtures.draft.items,
                postalCode: "123"
            )
        }
    }
}
