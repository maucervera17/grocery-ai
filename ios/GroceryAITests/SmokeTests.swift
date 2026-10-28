import Testing
@testable import GroceryAI

struct SmokeTests {
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
    func legacyProductsInferUsefulFallbackCategories() {
        #expect(ProductCategory.inferred(from: "Manzanas") == .produce)
        #expect(ProductCategory.inferred(from: "Leche entera") == .dairy)
        #expect(ProductCategory.inferred(from: "12 huevos") == .eggs)
        #expect(ProductCategory.inferred(from: "Producto desconocido") == .other)
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

    @Test @MainActor
    func addingAStoredProductReplacesItsDraftQuantity() {
        let appState = AppState(
            agentService: MockAgentService(),
            comparisonService: MockComparisonService()
        )
        appState.draft.items = [ProductRequest(name: "Leche", quantity: 1, unit: .liter)]

        appState.addProducts([ProductRequest(name: "Leche", quantity: 3, unit: .liter)])

        #expect(appState.draft.items.count == 1)
        #expect(appState.draft.items[0].quantity == 3)
    }

    @Test @MainActor
    func frequentProductsIncludeStoredImagesAndFrequency() {
        let appState = AppState(
            agentService: MockAgentService(),
            comparisonService: MockComparisonService()
        )
        appState.orders = MockFixtures.previousOrders

        let milk = appState.frequentProductOptions.first { $0.product.name == "Leche" }

        #expect(milk?.frequency == 2)
        #expect(milk?.imageURL != nil)
        #expect(appState.frequentProductOptions.count >= 10)
    }

    @Test @MainActor
    func retryingAFailedMessageDoesNotDuplicateTheUserMessage() async {
        let appState = AppState(
            agentService: AlwaysFailingAgentService(),
            comparisonService: MockComparisonService()
        )

        _ = await appState.send("2 litros de leche")
        _ = await appState.send("2 litros de leche")

        #expect(appState.messages.filter { $0.role == .user }.count == 1)
        #expect(appState.messages.filter { $0.kind == .error }.count == 1)
    }
}

private struct AlwaysFailingAgentService: AgentServicing {
    func updateDraft(
        message: String,
        currentItems: [ProductRequest]
    ) async throws -> AgentResponse {
        throw AgentServiceError.noProductsFound
    }
}
