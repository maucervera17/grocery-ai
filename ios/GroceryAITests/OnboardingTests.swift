import Testing
import UserNotifications
@testable import GroceryAI

struct SavingsEstimatorTests {
    @Test
    func estimatesEachSpendRange() {
        let cases: [(SpendRange, Int, Int)] = [
            (.under2000, 4_000, 9_000),
            (.between2000and4000, 12_000, 27_000),
            (.between4000and7000, 22_000, 50_000),
            (.between7000and10000, 34_000, 77_000),
            (.over10000, 48_000, 108_000)
        ]

        for (range, expectedLow, expectedHigh) in cases {
            let estimate = SavingsEstimator.estimate(spend: range, householdSize: .threeFour)
            #expect(estimate.lowCents == expectedLow, "\(range) low")
            #expect(estimate.highCents == expectedHigh, "\(range) high")
        }
    }

    @Test
    func unsureFallsBackToHouseholdScaledReference() {
        let solo = SavingsEstimator.estimate(spend: .unsure, householdSize: .solo)
        #expect(solo.lowCents == 12_000)
        #expect(solo.highCents == 27_000)

        let family = SavingsEstimator.estimate(spend: .unsure, householdSize: .threeFour)
        #expect(family.lowCents == 24_000)
        #expect(family.highCents == 54_000)
        #expect(family.annualHighCents == 648_000)

        let missingSpend = SavingsEstimator.estimate(spend: nil, householdSize: .threeFour)
        #expect(missingSpend == family)
    }

    @Test
    func roundsToNearestTenPesos() {
        // $5,500 * 9% = $495 -> $500; $5,500 * 4% = $220 -> $220
        let estimate = SavingsEstimator.estimate(spend: .between4000and7000, householdSize: .two)
        #expect(estimate.lowCents % 1_000 == 0)
        #expect(estimate.highCents % 1_000 == 0)
    }
}

@MainActor
struct OnboardingModelTests {
    private func makeModel(
        agent: any AgentServicing = MockAgentService(),
        comparison: any ComparisonServicing = MockComparisonService(),
        hasPassword: Bool = true
    ) -> OnboardingModel {
        let model = OnboardingModel(
            agentService: agent,
            comparisonService: comparison
        )
        model.hasAccessPassword = { hasPassword }
        model.accessSaver = { _ in }
        model.demoMinimumDuration = .zero
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
    func quizAdvancesThroughEveryQuestion() {
        let model = makeModel()
        let expected: [OnboardingStep] = [
            .intro, .householdSize, .frequency, .monthlySpend, .usualStores,
            .compareHabit, .insight, .goals, .painPoints, .listHabit, .postalCode
        ]
        var current: OnboardingStep = .welcome
        for step in expected {
            model.advance(from: current)
            #expect(model.path.last == step)
            current = step
        }
    }

    @Test
    func skippingPostalCodeLeavesItEmptyAndContinues() {
        let model = makeModel()
        model.push(.postalCode)

        model.skipPostalCode()

        #expect(model.answers.postalCode.isEmpty)
        #expect(model.path.last == .planLoader)
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
    func accessStepAppearsBeforeImportOnlyWithoutPassword() {
        #expect(makeModel(hasPassword: false).step(after: .benefits) == .access)
        #expect(makeModel(hasPassword: true).step(after: .benefits) == .importMethod)
        #expect(makeModel().step(after: .access) == .importMethod)
        #expect(OnboardingStep.access.showsBackButton)
        let order = OnboardingStep.progressOrder
        #expect(order.firstIndex(of: .access)! < order.firstIndex(of: .importMethod)!)
        #expect(order.firstIndex(of: .access)! > order.firstIndex(of: .benefits)!)
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
        #expect(model.path.last == .importMethod)
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
    func skippingAccessUsesSuggestedListAndSkipsTheComparison() {
        let model = makeModel(hasPassword: false)
        model.push(.access)

        model.skipAccess()

        #expect(model.accessSkipped)
        #expect(model.path.last == .importReview)
        #expect(model.answers.importMethod == .suggested)
        #expect(!model.answers.importedItems.isEmpty)
        #expect(model.step(after: .demoPick) == .demoResult)
        #expect(model.demoPlan == nil)
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
    func comparingScreenStaysForTheMinimumDuration() async {
        let model = makeModel()
        model.demoMinimumDuration = .milliseconds(400)
        model.answers.importedItems = OnboardingModel.suggestedItems(for: .threeFour)
        model.push(.demoComparing)
        let clock = ContinuousClock()
        let start = clock.now

        model.runDemoComparison()

        #expect(await waitForLastStep(.demoResult, in: model))
        #expect(start.duration(to: clock.now) >= .milliseconds(400))
    }

    @Test
    func introCountsTheRealQuestions() {
        #expect(OnboardingStep.questionSteps.count == 8)
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
    func demoResultAdvancesToPaywall() {
        let model = makeModel()
        model.push(.demoResult)

        model.advance(from: .demoResult)

        #expect(model.path.last == .paywall)
    }

    @Test
    func importMethodPreselectionFollowsListHabit() {
        #expect(ImportMethod(listHabit: .paper) == .camera)
        #expect(ImportMethod(listHabit: .notes) == .paste)
        #expect(ImportMethod(listHabit: .whatsapp) == .paste)
        #expect(ImportMethod(listHabit: .reminders) == .paste)
        #expect(ImportMethod(listHabit: .memory) == .dictate)
        #expect(ImportMethod(listHabit: .noList) == .suggested)
        #expect(ImportMethod(listHabit: nil) == .suggested)
    }

    @Test
    func listHabitSelectionSetsRecommendedImportMethod() {
        let model = makeModel()
        model.select(.paper)
        #expect(model.answers.importMethod == .camera)
    }

    @Test
    func demoTimeoutProducesFailureState() async {
        let model = makeModel(comparison: SlowComparisonService(delay: .seconds(5)))
        model.demoSoftCap = .milliseconds(10)
        model.demoHardCap = .milliseconds(50)
        model.notificationStatusProvider = { .authorized }
        model.answers.importedItems = OnboardingModel.suggestedItems(for: .threeFour)
        model.push(.demoComparing)

        model.runDemoComparison()

        #expect(await waitForLastStep(.demoResult, in: model))
        #expect(model.demoFailed)
        #expect(model.demoPlan == nil)

        model.advance(from: .demoResult)
        #expect(await waitForLastStep(.paywall, in: model))
    }

    @Test
    func demoSuccessDeliversPlan() async {
        let model = makeModel()
        model.demoSoftCap = .milliseconds(50)
        model.demoHardCap = .seconds(5)
        model.notificationStatusProvider = { .authorized }
        model.answers.postalCode = "06700"
        model.answers.importedItems = OnboardingModel.suggestedItems(for: .threeFour)
        model.push(.demoComparing)

        model.runDemoComparison()

        #expect(await waitForLastStep(.demoResult, in: model))
        #expect(!model.demoFailed)
        #expect(model.demoPlan != nil)

        model.advance(from: .demoResult)
        #expect(await waitForLastStep(.paywall, in: model))
    }
}

private struct FailingAgentService: AgentServicing {
    func updateDraft(message: String, currentItems: [ProductRequest]) async throws -> AgentResponse {
        throw AgentServiceError.noProductsFound
    }
}

private struct SlowComparisonService: ComparisonServicing {
    let delay: Duration

    func compare(
        items: [ProductRequest],
        postalCode: String
    ) async throws -> ComparisonPlan {
        try await Task.sleep(for: delay)
        return MockFixtures.comparisonPlan
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
            comparisonService: MockComparisonService()
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
        #expect(context.estimatedMonthlySavingsHighCents == model.savingsEstimate.highCents)
    }
}
