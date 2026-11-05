import Foundation
import Observation
import UserNotifications

@MainActor
@Observable
final class OnboardingModel {
    var answers = OnboardingAnswers()
    var path: [OnboardingStep] = []
    var didViewPaywall = false

    var isVerifyingAccess = false
    var accessErrorMessage: String?
    var hasVerifiedAccess = false
    /// The user chose "No tengo contraseña": the demo can't call the API.
    var accessSkipped = false

    var isImportingList = false
    var importErrorMessage: String?

    var demoItems: [ProductRequest] = []
    var isComparingDemo = false
    var showsDemoSlowMessage = false
    var demoPlan: ComparisonPlan?
    var demoFailed = false
    private(set) var demoOutcomeDelivered = false

    private let agentService: any AgentServicing
    private let comparisonService: any ComparisonServicing
    private var demoTask: Task<Void, Never>?

    var demoSoftCap: Duration = .seconds(12)
    var demoHardCap: Duration = .seconds(45)
    /// Keeps "Comparando" on screen long enough to read when the API is fast.
    var demoMinimumDuration: Duration = .milliseconds(1500)

    var hasAccessPassword: @MainActor () -> Bool = { APIAccess.hasPassword }
    var accessVerifier: @Sendable (String) async -> APIAccess.Verification = {
        await APIAccess.verify(password: $0)
    }
    var accessSaver: @MainActor (String) throws -> Void = {
        try APIAccess.savePassword($0)
    }

    var notificationStatusProvider: @Sendable () async -> UNAuthorizationStatus = {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    var notificationAuthorizationRequester: @Sendable () async -> Bool = {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    var trialReminderScheduler: @Sendable () -> Void = {
        let content = UNMutableNotificationContent()
        content.title = "Barasu"
        content.body = "Tu prueba de Barasu termina en 2 días"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 5 * 24 * 60 * 60,
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "barasu.trialReminder",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    init(
        agentService: any AgentServicing = GroceryAPIClient(),
        comparisonService: any ComparisonServicing = GroceryAPIClient()
    ) {
        self.agentService = agentService
        self.comparisonService = comparisonService
    }

    var suggestedItems: [ProductRequest] {
        Self.suggestedItems(for: answers.householdSize)
    }

    static func suggestedItems(for householdSize: HouseholdSize?) -> [ProductRequest] {
        let multiplier = (householdSize ?? .threeFour).spendMultiplier
        return [
            (MockFixtures.milk, 1.0),
            (MockFixtures.eggs, 1.0),
            (MockFixtures.rice, 1.0),
            (MockFixtures.chicken, 1.0),
            (MockFixtures.toiletPaper, 0.5)
        ].map { template, weight in
            let scaled = max(1, (template.quantity * weight * multiplier).rounded())
            return ProductRequest(
                name: template.name,
                quantity: scaled,
                unit: template.unit,
                notes: template.notes,
                categoryID: template.categoryID
            )
        }
    }

    var savingsEstimate: SavingsEstimator.Estimate {
        SavingsEstimator.estimate(
            spend: answers.monthlySpend,
            householdSize: answers.householdSize
        )
    }

    func step(after step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .welcome: .intro
        case .intro: .householdSize
        case .householdSize: .frequency
        case .frequency: .monthlySpend
        case .monthlySpend: .usualStores
        case .usualStores: .compareHabit
        case .compareHabit: .insight
        case .insight: .goals
        case .goals: .painPoints
        case .painPoints: .listHabit
        case .listHabit: .postalCode
        case .postalCode: .planLoader
        case .planLoader: .savingsResult
        case .savingsResult: .benefits
        case .benefits: hasAccessPassword() ? .importMethod : .access
        case .access: .importMethod
        case .importMethod: .importReview
        case .importReview: .demoPick
        case .demoPick: accessSkipped ? .demoResult : .demoComparing
        case .demoComparing: .demoResult
        case .demoResult: .paywall
        case .paywall: nil
        }
    }

    func advance(from step: OnboardingStep) {
        guard let next = self.step(after: step) else { return }
        push(next)
    }

    func push(_ step: OnboardingStep) {
        if step == .paywall, !didViewPaywall {
            didViewPaywall = true
            OnboardingEvent.paywallViewed.log()
        }
        path.append(step)
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }



    func select(_ value: HouseholdSize) {
        answers.householdSize = value
        OnboardingEvent.answer(step: .householdSize, value: value.rawValue).log()
    }

    func select(_ value: ShoppingFrequency) {
        answers.shoppingFrequency = value
        OnboardingEvent.answer(step: .frequency, value: value.rawValue).log()
    }

    func select(_ value: SpendRange) {
        answers.monthlySpend = value
        OnboardingEvent.answer(step: .monthlySpend, value: value.rawValue).log()
    }

    func toggle(_ value: StoreChoice) {
        if answers.usualStores.contains(value) {
            answers.usualStores.remove(value)
        } else {
            answers.usualStores.insert(value)
        }
    }

    func select(_ value: CompareHabit) {
        answers.comparesToday = value
        OnboardingEvent.answer(step: .compareHabit, value: value.rawValue).log()
    }

    func toggle(_ value: ShoppingGoal) {
        if let index = answers.goals.firstIndex(of: value) {
            answers.goals.remove(at: index)
        } else if answers.goals.count < 2 {
            answers.goals.append(value)
        }
    }

    func toggle(_ value: PainPoint) {
        if answers.painPoints.contains(value) {
            answers.painPoints.remove(value)
        } else {
            answers.painPoints.insert(value)
        }
    }

    func select(_ value: ListHabit) {
        answers.listHabit = value
        answers.importMethod = ImportMethod(listHabit: value)
        OnboardingEvent.answer(step: .listHabit, value: value.rawValue).log()
    }

    func skipPostalCode() {
        answers.postalCode = ""
        advance(from: .postalCode)
    }


    func warmUpBackend() {
        let url = APIConfiguration.baseURL.appending(path: "health")
        Task.detached(priority: .utility) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            _ = try? await URLSession.shared.data(for: request)
        }
    }


    func submitAccess(_ password: String) async {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isVerifyingAccess else { return }
        isVerifyingAccess = true
        accessErrorMessage = nil
        let result = await accessVerifier(trimmed)
        isVerifyingAccess = false
        switch result {
        case .valid:
            do {
                try accessSaver(trimmed)
            } catch {
                accessErrorMessage = "No pudimos guardar tu contraseña en este iPhone. Intenta de nuevo."
                return
            }
            hasVerifiedAccess = true
            accessSkipped = false
            OnboardingEvent.accessVerified.log()
            advance(from: .access)
        case .invalid:
            accessErrorMessage = "Esa contraseña no es válida. Revísala e intenta de nuevo."
        case .unreachable:
            accessErrorMessage = "No pudimos conectar con Barasu. Revisa tu internet e intenta de nuevo."
        }
    }

    func skipAccess() {
        accessSkipped = true
        accessErrorMessage = nil
        importErrorMessage = nil
        answers.importMethod = .suggested
        answers.importedItems = suggestedItems
        OnboardingEvent.accessSkipped.log()
        push(.importReview)
    }

    func useSuggestedList() {
        applySuggestedList()
        advance(from: .importMethod)
    }

    /// Replaces a failed import with the suggested list without leaving the review step.
    func applySuggestedList() {
        answers.importMethod = .suggested
        answers.importedItems = suggestedItems
        importErrorMessage = nil
        OnboardingEvent.importMethod(.suggested).log()
    }

    func showUnreadablePhoto() {
        answers.importedItems = []
        importErrorMessage = Self.unrecognizedListMessage(for: .camera)
        if path.last != .importReview {
            push(.importReview)
        }
    }

    static func unrecognizedListMessage(for method: ImportMethod?) -> String {
        switch method {
        case .camera:
            "No encontré productos en la foto. Prueba con otra foto con buena luz o pega tu lista como texto."
        case .paste:
            "No reconocí productos en el texto que pegaste. Pon un producto por línea o sepáralos con comas."
        default:
            "No reconocí productos en tu lista. Pon un producto por línea o sepáralos con comas."
        }
    }

    static func importErrorMessage(for error: any Error, method: ImportMethod?) -> String {
        if let apiError = error as? GroceryAPIError {
            return apiError.isAccessProblem
                ? "No tienes acceso al servidor de precios. Usa una lista sugerida y agrega tu contraseña después en Ajustes."
                : "El servidor de Barasu no respondió. Intenta de nuevo en un momento."
        }
        if error is URLError {
            return "No pudimos conectar con Barasu. Revisa tu internet e intenta de nuevo."
        }
        return unrecognizedListMessage(for: method)
    }

    func importList(from text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if path.last != .importReview {
            push(.importReview)
        }
        isImportingList = true
        importErrorMessage = nil
        do {
            let response = try await agentService.updateDraft(
                message: trimmed,
                currentItems: []
            )
            answers.importedItems = response.draftItems
            isImportingList = false
            if response.draftItems.isEmpty {
                importErrorMessage = Self.unrecognizedListMessage(for: answers.importMethod)
            }
        } catch {
            isImportingList = false
            answers.importedItems = []
            importErrorMessage = Self.importErrorMessage(for: error, method: answers.importMethod)
        }
    }

    func updateImportedItem(_ product: ProductRequest) {
        guard let index = answers.importedItems.firstIndex(where: { $0.id == product.id }) else { return }
        answers.importedItems[index] = product
    }

    func removeImportedItems(at offsets: IndexSet) {
        answers.importedItems.remove(atOffsets: offsets)
    }


    func runDemoComparison() {
        guard !isComparingDemo, !demoOutcomeDelivered else { return }
        isComparingDemo = true
        showsDemoSlowMessage = false

        let items = demoItems.isEmpty
            ? Array(answers.importedItems.prefix(2))
            : demoItems
        let postalCode = answers.postalCode
        let comparisonService = self.comparisonService
        let softCap = demoSoftCap
        let hardCap = demoHardCap
        let minimumDuration = demoMinimumDuration
        let clock = ContinuousClock()
        let startedAt = clock.now

        demoTask = Task { [weak self] in
            let slowMessageTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: softCap)
                guard !Task.isCancelled else { return }
                self?.showsDemoSlowMessage = true
            }

            let plan = await withTaskGroup(of: ComparisonPlan?.self) { group in
                group.addTask {
                    try? await comparisonService.compare(
                        items: items,
                        postalCode: postalCode
                    )
                }
                group.addTask {
                    try? await Task.sleep(for: hardCap)
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first ?? nil
            }

            let elapsed = startedAt.duration(to: clock.now)
            if elapsed < minimumDuration {
                try? await Task.sleep(for: minimumDuration - elapsed)
            }
            slowMessageTask.cancel()
            guard let self, !Task.isCancelled else { return }
            isComparingDemo = false
            demoOutcomeDelivered = true
            if let plan {
                demoPlan = plan
                demoFailed = false
                OnboardingEvent.demoFinished(savingsCents: plan.estimatedSavingsCents ?? 0).log()
            } else {
                demoFailed = true
                OnboardingEvent.demoFailed.log()
            }
            advance(from: .demoComparing)
        }
    }


    func requestNotificationAuthorizationIfNeeded() async {
        guard await notificationStatusProvider() == .notDetermined else { return }
        _ = await notificationAuthorizationRequester()
    }


    var prioritizedPaywallBenefits: [PaywallBenefit] {
        var ordered: [PaywallBenefit] = []
        func add(_ benefit: PaywallBenefit) {
            if !ordered.contains(benefit) { ordered.append(benefit) }
        }

        for goal in answers.goals {
            switch goal {
            case .saveMoney: add(.compare)
            case .saveTime: add(.dictate)
            case .forgetNothing, .organize: add(.history)
            }
        }
        for pain in PainPoint.allCases where answers.painPoints.contains(pain) {
            switch pain {
            case .overspend, .dontKnowCheapest: add(.compare)
            case .listTakesTime: add(.dictate)
            case .forgetThings, .repeatList: add(.history)
            }
        }
        add(.compare)
        add(.dictate)
        add(.history)
        return ordered
    }

    func makePaywallContext() -> PaywallContext {
        PaywallContext(
            estimatedMonthlySavingsHighCents: savingsEstimate.highCents,
            demoSavingsCents: demoPlan?.estimatedSavingsCents,
            demoProductCount: demoPlan.map {
                $0.stores.reduce(0) { $0 + $1.items.count }
            } ?? min(2, answers.importedItems.count),
            cadencePhrase: answers.shoppingFrequency?.cadencePhrase,
            prioritizedBenefits: prioritizedPaywallBenefits,
            householdLabel: answers.householdSize?.title,
            frequencyLabel: answers.shoppingFrequency?.title,
            postalCode: answers.postalCode.isEmpty ? nil : answers.postalCode,
            listItemCount: answers.importedItems.count
        )
    }

    func handleSubscribed(
        plan: SubscriptionPlanID,
        appState: AppState,
        onFinished: () -> Void
    ) {
        OnboardingEvent.subscribed(plan).log()
        if plan == .annual {
            Task {
                let status = await notificationStatusProvider()
                if status == .authorized {
                    trialReminderScheduler()
                }
            }
        }
        appState.completeOnboarding(
            items: answers.importedItems,
            postalCode: answers.postalCode
        )
        OnboardingEvent.finished.log()
        onFinished()
    }

    #if DEBUG
    func seedSampleAnswers() {
        answers.householdSize = .threeFour
        answers.shoppingFrequency = .weekly
        answers.monthlySpend = .between4000and7000
        answers.usualStores = [.walmart, .chedraui]
        answers.comparesToday = .sometimes
        answers.goals = [.saveMoney, .forgetNothing]
        answers.painPoints = [.dontKnowCheapest, .forgetThings]
        answers.listHabit = .notes
        answers.postalCode = "06700"
        answers.importMethod = .paste
        answers.importedItems = MockFixtures.draft.items
        demoItems = MockFixtures.draft.items
        demoPlan = MockFixtures.comparisonPlan
        demoOutcomeDelivered = true
        if ProcessInfo.processInfo.arguments.contains("-onboardingDemoFail") {
            demoPlan = nil
            demoFailed = true
        }
    }
    #endif
}
