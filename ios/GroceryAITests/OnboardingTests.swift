import Testing
import UserNotifications
@testable import GroceryAI

@MainActor
struct OnboardingModelTests {
    private func makeModel(
        agent: any AgentServicing = MockAgentService(),
        basket: any BasketQuoting = MockBasketService(delay: .zero),
        hasPassword: Bool = true
    ) -> OnboardingModel {
        let model = OnboardingModel(
            agentService: agent,
            basketService: basket
        )
        model.hasAccessPassword = { hasPassword }
        model.accessSaver = { _ in }
        model.minimumLineDuration = .zero
        model.autoAdvanceDelay = .zero
        return model
    }

    private func waitForLastStep(
        _ step: OnboardingStep,
        in model: OnboardingModel
    ) async -> Bool {
        for _ in 0..<40 where model.path.last != step {
            try? await Task.sleep(for: .milliseconds(25))
        }
        return model.path.last == step
    }


    @Test
    func skippingPostalCodeLeavesItEmptyAndContinues() {
        let model = makeModel()
        model.push(.postalCode)

        model.skipPostalCode()

        #expect(model.answers.postalCode.isEmpty)
        #expect(model.path.last == .comparisonStores)
    }

    @Test
    func skippingImportUsesTheSuggestedList() {
        let model = makeModel()
        model.answers.householdSize = .solo
        model.push(.importMethod)

        model.useSuggestedList()

        #expect(model.path.last == .importReview)
        #expect(model.answers.importMethod == .suggested)
        #expect(!model.answers.importedItems.isEmpty)
    }


    @Test
    func validAccessPasswordIsSavedAndAdvances() async {
        let model = makeModel(hasPassword: false)
        var saved: String?
        model.accessVerifier = { $0 == "correcta" ? .valid : .invalid }
        model.accessSaver = { saved = $0 }
        model.push(.access)

        await model.submitAccess("  correcta \n")

        #expect(saved == "correcta")
        #expect(model.hasVerifiedAccess)
        #expect(model.accessErrorMessage == nil)
        #expect(model.path.last == .planLoader)
    }

    @Test
    func invalidOrUnreachableAccessShowsInlineErrorAndStays() async {
        let model = makeModel(hasPassword: false)
        var saved = false
        model.accessSaver = { _ in saved = true }
        model.push(.access)

        model.accessVerifier = { _ in .invalid }
        await model.submitAccess("mala")
        #expect(model.accessErrorMessage?.contains("no es válida") == true)
        #expect(model.path.last == .access)

        model.accessVerifier = { _ in .unreachable }
        await model.submitAccess("mala")
        #expect(model.accessErrorMessage?.contains("conectar") == true)
        #expect(model.path.last == .access)
        #expect(!saved)
        #expect(!model.hasVerifiedAccess)
    }


    @Test
    func importErrorsExplainTheRealCause() {
        let access = OnboardingModel.importErrorMessage(
            for: GroceryAPIError(message: "x", isAccessProblem: true), method: .paste
        )
        #expect(access.contains("acceso"))
        let network = OnboardingModel.importErrorMessage(for: URLError(.notConnectedToInternet), method: .paste)
        #expect(network.contains("internet"))
        let parse = OnboardingModel.importErrorMessage(for: AgentServiceError.noProductsFound, method: .paste)
        #expect(parse.contains("pegaste"))
        #expect(!parse.contains("foto"))
        #expect(OnboardingModel.unrecognizedListMessage(for: .camera).contains("foto"))
    }

    @Test
    func failedImportCanFallBackToSuggestedList() async {
        let model = makeModel(agent: FailingAgentService())
        model.answers.importMethod = .paste
        model.push(.importMethod)

        await model.importList(from: "leche")
        #expect(model.path.last == .importReview)
        #expect(model.importErrorMessage != nil)
        #expect(model.answers.importedItems.isEmpty)

        model.applySuggestedList()
        #expect(model.importErrorMessage == nil)
        #expect(model.answers.importMethod == .suggested)
        #expect(!model.answers.importedItems.isEmpty)
        #expect(model.path.last == .importReview)
    }



    @Test
    func postalCodeValidationRejectsImpossibleCodes() {
        #expect(PostalCodeStep.isValid("06700"))
        #expect(PostalCodeStep.isValid("01000"))
        #expect(!PostalCodeStep.isValid("00000"))
        #expect(!PostalCodeStep.isValid("00999"))
        #expect(!PostalCodeStep.isValid("0670"))
        #expect(!PostalCodeStep.isValid("０６７００"))
    }

    @Test
    func pasteCounterCountsCommaSeparatedItems() {
        #expect(ImportListTextSheet.itemCount(in: "Leche, huevos, arroz y papel de baño") == 4)
        #expect(ImportListTextSheet.itemCount(in: "Leche 2 L\nHuevo 12 piezas\n\nArroz 1 kg") == 3)
        #expect(ImportListTextSheet.itemCount(in: "Queso 1,5 kg") == 1)
        #expect(ImportListTextSheet.itemCount(in: "   ") == 0)
    }

    @Test
    func productNamesAreCapitalizedForDisplay() {
        #expect(ProductNameFormatter.display("papel de baño") == "Papel de baño")
        #expect(ProductNameFormatter.display("Leche") == "Leche")
        #expect(ProductNameFormatter.display("") == "")
    }





    @Test
    func flowFollowsTheApprovedOrder() {
        let model = makeModel()
        #expect(model.step(after: .welcome) == .householdSize)
        #expect(model.step(after: .householdSize) == .frequency)
        #expect(model.step(after: .frequency) == .usualStore)
        #expect(model.step(after: .usualStore) == .postalCode)
        #expect(model.step(after: .postalCode) == .comparisonStores)
        #expect(model.step(after: .comparisonStores) == .planLoader)
        #expect(model.step(after: .planLoader) == .basketResult)
        #expect(model.step(after: .basketResult) == .importMethod)
        #expect(model.step(after: .importMethod) == .importReview)
        #expect(model.step(after: .importReview) == .paywall)
    }

    @Test
    func accessAppearsRightBeforeTheFirstQuoteOnlyWithoutPassword() {
        let model = makeModel(hasPassword: false)
        #expect(model.step(after: .comparisonStores) == .access)
        #expect(model.step(after: .access) == .planLoader)
    }

    @Test
    func skippingAccessShowsHonestResultAndSuggestedList() {
        let model = makeModel(hasPassword: false)
        model.path = [.access]
        model.skipAccess()
        #expect(model.path.last == .basketResult)
        #expect(model.step(after: .basketResult) == .importReview)
        #expect(!model.answers.importedItems.isEmpty)
    }

    @Test
    func singleChoiceAdvancesOnTap() async {
        let model = makeModel()
        model.path = [.frequency]
        model.select(.everyThreeWeeks)
        model.autoAdvance(from: .frequency)
        #expect(await waitForLastStep(.usualStore, in: model))
    }

    @Test
    func usualStoreIsSingleAndPreselectedForComparison() {
        let model = makeModel()
        model.selectUsualStore(.walmart)
        model.selectUsualStore(.chedraui)
        #expect(model.answers.usualStore == .chedraui)
        #expect(model.answers.comparisonStores == [.chedraui])
        model.selectUsualStore(.soriana)
        #expect(model.answers.comparisonStores.isEmpty)
        model.toggleComparisonStore(.laComer)
        #expect(model.answers.comparisonStores.isEmpty)
    }

    @Test
    func comingSoonAndBaseOnlyStoresCannotBeCompared() {
        #expect(!StoreChoice.supported.contains(.soriana))
        #expect(StoreChoice.comingSoon == [.soriana, .laComer])
        #expect(!StoreChoice.allCases.map(\.rawValue).contains("costco"))
        #expect(StoreChoice.mercado.unsupportedNotice != nil)
        #expect(StoreChoice.walmart.unsupportedNotice == nil)
    }

    @Test
    func everyThreeWeeksIsAboutOnePointFourTripsAMonth() {
        #expect(ShoppingFrequency.everyThreeWeeks.tripsPerMonth == 1.43)
        #expect(ShoppingFrequency.allCases.contains(.everyThreeWeeks))
    }

    @Test
    func basketQuoteChecksEachStoreAndBuildsTheEstimate() async {
        let model = makeModel()
        model.answers.householdSize = .threeFour
        model.answers.shoppingFrequency = .weekly
        model.selectUsualStore(.walmart)
        model.toggleComparisonStore(.chedraui)
        model.path = [.planLoader]
        model.runBasketQuote()
        #expect(await waitForLastStep(.basketResult, in: model))
        #expect(model.quoteStatuses[.walmart] == .done)
        #expect(model.quoteStatuses[.chedraui] == .done)
        #expect(model.quoteStatuses[.bodegaAurrera] == nil)
        let estimate = try? #require(model.basketEstimate)
        // Avena is not sold in the mock Walmart, so only 3 items compare.
        #expect(estimate?.comparableItemCount == 3)
        #expect(estimate?.baseMonthlyCents == 7_900 * 3 + 2_850 * 16 + 4_200 * 2)
        #expect(estimate?.chosenMonthlyCents == 7_650 * 3 + 2_650 * 16 + 3_990 * 2)
        #expect(model.makePaywallContext().basketSavingsMonthlyCents == estimate?.savingsMonthlyCents)
    }

    @Test
    func failedStoreIsMarkedAndNeverPriced() async {
        let model = makeModel(basket: MockBasketService(delay: .zero, failingRetailers: [.walmart]))
        model.selectUsualStore(.walmart)
        model.toggleComparisonStore(.bodegaAurrera)
        model.path = [.planLoader]
        model.runBasketQuote()
        #expect(await waitForLastStep(.basketResult, in: model))
        #expect(model.quoteStatuses[.walmart] == .failed)
        #expect(model.basketEstimate?.baseMonthlyCents == nil)
        #expect(model.basketEstimate?.savingsMonthlyCents == nil)
    }
}

@MainActor
struct BasketEstimateTests {
    private func quotes(_ retailers: [RetailerID]) async -> [BasketQuote] {
        var result: [BasketQuote] = []
        for retailer in retailers {
            if let quote = try? await MockBasketService(delay: .zero).quoteBasket(retailer: retailer, postalCode: nil) {
                result.append(quote)
            }
        }
        return result
    }

    @Test
    func householdScalesQuantities() async {
        let quoted = await quotes([.chedraui])
        let family = BasketEstimate.make(quotes: quoted, baseStore: .chedraui, comparisonStores: [.chedraui], householdSize: .threeFour, frequency: .weekly)
        let solo = BasketEstimate.make(quotes: quoted, baseStore: .chedraui, comparisonStores: [.chedraui], householdSize: .solo, frequency: .weekly)
        #expect((solo?.baseMonthlyCents ?? 0) * 2 == family?.baseMonthlyCents)
        #expect(family?.savingsMonthlyCents == 0)
    }

    @Test
    func unsupportedBaseNeverClaimsSavings() async {
        let quoted = await quotes([.bodegaAurrera, .chedraui])
        let estimate = BasketEstimate.make(quotes: quoted, baseStore: .soriana, comparisonStores: [.bodegaAurrera, .chedraui], householdSize: .threeFour, frequency: .weekly)
        #expect(estimate?.baseMonthlyCents == nil)
        #expect(estimate?.savingsMonthlyCents == nil)
        #expect(estimate?.chosenMonthlyCents != nil)
        #expect(estimate?.storeTotals.count == 2)
    }

    @Test
    func missingProductIsShownAsUnavailable() async {
        let quoted = await quotes([.walmart, .chedraui])
        let estimate = BasketEstimate.make(quotes: quoted, baseStore: .walmart, comparisonStores: [.walmart, .chedraui], householdSize: .threeFour, frequency: .weekly)
        let avena = estimate?.rows.first { $0.id == "avena" }
        #expect(avena?.prices[.walmart] == .some(nil))
        #expect(estimate?.storeTotals.first { $0.retailerID == .walmart }?.missingItemNames == ["Avena Quaker 400 g"])
    }

    @Test
    func monthlyCostIsPerTripCostTimesTrips() async {
        let quoted = await quotes([.chedraui])
        let estimate = BasketEstimate.make(quotes: quoted, baseStore: .chedraui, comparisonStores: [.chedraui], householdSize: .threeFour, frequency: .everyThreeWeeks)
        let monthly = estimate?.baseMonthlyCents ?? 0
        let perTrip = estimate?.perTripCents(monthly) ?? 0
        #expect(abs(Double(perTrip) * 1.43 - Double(monthly)) < 1.43)
    }

    @Test
    func spendAdjustmentKeepsTheQuotedRatio() async {
        let quoted = await quotes([.walmart, .chedraui])
        let estimate = BasketEstimate.make(quotes: quoted, baseStore: .walmart, comparisonStores: [.walmart, .chedraui], householdSize: .threeFour, frequency: .weekly)
        let adjusted = estimate?.adjusted(toMonthlySpendCents: 550_000)
        #expect(adjusted?.base == 550_000)
        #expect((adjusted?.savings ?? 0) > 0)
    }

    @Test func perKiloItemsShowKilosPerMonth() {
        #expect(BasketResultStep.packages(3, perKilo: true) == "3 kg")
        #expect(BasketResultStep.packages(1.5, perKilo: true) == "1.5 kg")
        #expect(BasketResultStep.packages(1) == "1 paquete")
    }
}

@MainActor
struct OnboardingProfileTests {
    @Test
    func completeOnboardingKeepsTheProfileForTheAgent() {
        let appState = AppState(agentService: MockAgentService(), comparisonService: MockComparisonService())
        var answers = OnboardingAnswers()
        answers.householdSize = .two
        answers.shoppingFrequency = .everyThreeWeeks
        answers.usualStore = .soriana
        answers.comparisonStores = [.chedraui, .walmart]
        answers.postalCode = "06700"
        appState.completeOnboarding(items: [], postalCode: "06700", profile: answers.profile)
        #expect(appState.shoppingProfile.usualStore == "soriana")
        #expect(appState.shoppingProfile.comparisonStores == ["walmart", "chedraui"])
        #expect(appState.shoppingProfile.shoppingFrequency == "everyThreeWeeks")
        #expect(appState.messages.last?.text.contains("Walmart y Chedraui") == true)
    }
}

private struct FailingAgentService: AgentServicing {
    func updateDraft(message: String, currentItems: [ProductRequest]) async throws -> AgentResponse {
        throw AgentServiceError.noProductsFound
    }
}

@Suite(.serialized)
@MainActor
struct PaywallContextTests {
    @Test
    func paywallDatesComputeReminderAndCharge() {
        let now = Date(timeIntervalSince1970: 1_762_204_800)
        let dates = PaywallDates(now: now)

        #expect(dates.reminderDate.timeIntervalSince(now) == 5 * 86_400)
        #expect(dates.chargeDate.timeIntervalSince(now) == 7 * 86_400)
    }

    @Test
    func paywallDatesFormatEsMX() {
        let dates = PaywallDates(now: Date(timeIntervalSince1970: 1_762_204_800))
        let formatted = dates.formatted(dates.chargeDate)

        #expect(!formatted.isEmpty)
        #expect(formatted.range(of: #"\d+"#, options: .regularExpression) != nil)
    }

    @Test
    func modelFillsPaywallContextFromAnswers() {
        let model = OnboardingModel(
            agentService: MockAgentService(),
            basketService: MockBasketService(delay: .zero)
        )
        model.hasAccessPassword = { true }
        model.answers.householdSize = .threeFour
        model.answers.shoppingFrequency = .weekly
        model.answers.postalCode = "06700"
        model.answers.importedItems = MockFixtures.draft.items

        let context = model.makePaywallContext()

        #expect(context.householdLabel == model.answers.householdSize?.title)
        #expect(context.frequencyLabel == model.answers.shoppingFrequency?.title)
        #expect(context.postalCode == "06700")
        #expect(context.listItemCount == MockFixtures.draft.items.count)
        #expect(context.basketSavingsMonthlyCents == nil)
    }
}

struct NearbyStoresTests {
    @Test func placeNamesMatchOnlyTheQuotedChains() {
        #expect(NearbyStoresFinder.store(forPlaceName: "Walmart Supercenter Universidad") == .walmart)
        #expect(NearbyStoresFinder.store(forPlaceName: "Walmart Express Narvarte") == nil)
        #expect(NearbyStoresFinder.store(forPlaceName: "Sam's Club Universidad") == nil)
        #expect(NearbyStoresFinder.store(forPlaceName: "Mi Bodega Aurrera") == .bodegaAurrera)
        #expect(NearbyStoresFinder.store(forPlaceName: "Bodega Aurrera Express") == .bodegaAurrera)
        #expect(NearbyStoresFinder.store(forPlaceName: "Chedraui Selecto") == .chedraui)
        #expect(NearbyStoresFinder.store(forPlaceName: "Soriana Híper") == nil)
        #expect(NearbyStoresFinder.store(forPlaceName: "Costco") == nil)
    }

    @Test func summaryListsTheNearestBranchOfEachChain() {
        func branch(_ store: StoreChoice, _ id: String, _ distance: Double) -> NearbyStore {
            NearbyStore(id: id, store: store, name: store.title, latitude: 0, longitude: 0, distance: distance)
        }
        let nearest = NearbyStoresFinder.nearestPerChain([
            branch(.walmart, "a", 2_300), branch(.chedraui, "b", 1_240), branch(.walmart, "c", 760), branch(.bodegaAurrera, "d", 320)
        ])
        #expect(nearest.map(\.id) == ["d", "c", "b"])
        #expect(NearbyStoresFinder.summary(for: nearest)
            == "3 sucursales cerca de tu CP: Bodega Aurrera a 300 m, Walmart a 800 m y Chedraui a 1.2 km.")
        #expect(NearbyStoresFinder.summary(for: [branch(.chedraui, "b", 1_240)]) == "1 sucursal cerca de tu CP: Chedraui a 1.2 km.")
        #expect(NearbyStoresFinder.summary(for: []).hasPrefix("No encontramos"))
    }
}
