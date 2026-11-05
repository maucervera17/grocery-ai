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
        comparison: any ComparisonServicing = MockComparisonService()
    ) -> OnboardingModel {
        OnboardingModel(
            agentService: MockAgentService(),
            comparisonService: comparison
        )
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
