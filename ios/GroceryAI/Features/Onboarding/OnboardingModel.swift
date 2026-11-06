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

    enum QuoteStatus: Equatable, Sendable {
        case loading
        case done
        case failed
    }

    var quoteStatuses: [StoreChoice: QuoteStatus] = [:]
    var basketQuotes: [BasketQuote] = []
    var basketEstimate: BasketEstimate?
    var basketFailed = false
    private(set) var basketDelivered = false

    private let agentService: any AgentServicing
    private let basketService: any BasketQuoting
    private var basketTask: Task<Void, Never>?

    /// Each store line stays on screen at least this long so it can be read.
    var minimumLineDuration: Duration = .milliseconds(900)
    var basketHardCap: Duration = .seconds(25)
    /// Single-choice questions advance on tap after this pause.
    var autoAdvanceDelay: Duration = .milliseconds(250)

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
        basketService: any BasketQuoting = GroceryAPIClient()
    ) {
        self.agentService = agentService
        self.basketService = basketService
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

    func step(after step: OnboardingStep) -> OnboardingStep? {
        switch step {
        case .welcome: .householdSize
        case .householdSize: .frequency
        case .frequency: .usualStore
        case .usualStore: .postalCode
        case .postalCode: .comparisonStores
        case .comparisonStores: hasAccessPassword() ? .planLoader : .access
        case .access: accessSkipped ? .basketResult : .planLoader
        case .planLoader: .basketResult
        case .basketResult: accessSkipped ? .importReview : .importMethod
        case .importMethod: .importReview
        case .importReview: .paywall
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

    func selectUsualStore(_ value: StoreChoice) {
        if let previous = answers.usualStore, previous != value {
            answers.comparisonStores.remove(previous)
        }
        answers.usualStore = value
        if value.isSupportedByBarasu {
            answers.comparisonStores.insert(value)
        }
        OnboardingEvent.answer(step: .usualStore, value: value.rawValue).log()
    }

    func toggleComparisonStore(_ value: StoreChoice) {
        guard value.isSupportedByBarasu else { return }
        if answers.comparisonStores.contains(value) {
            answers.comparisonStores.remove(value)
        } else {
            answers.comparisonStores.insert(value)
        }
    }

    func continueFromComparisonStores() {
        guard !answers.comparisonStores.isEmpty else { return }
        OnboardingEvent.answer(
            step: .comparisonStores,
            value: answers.orderedComparisonStores.map(\.rawValue).joined(separator: ",")
        ).log()
        resetBasketQuote()
        advance(from: .comparisonStores)
    }

    /// Advances after a single-choice tap, leaving the selection visible briefly.
    func autoAdvance(from step: OnboardingStep) {
        let delay = autoAdvanceDelay
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, self.currentStep == step else { return }
            self.advance(from: step)
        }
    }

    var currentStep: OnboardingStep { path.last ?? .welcome }

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
        advance(from: .access)
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


    /// Supported stores to quote: the chosen ones plus a supported base store.
    var quotedStores: [StoreChoice] {
        var stores = Set(answers.comparisonStores)
        if let base = answers.usualStore, base.isSupportedByBarasu {
            stores.insert(base)
        }
        return StoreChoice.supported.filter { stores.contains($0) }
    }

    var displayedFigures: (base: Int?, chosen: Int?, savings: Int?) {
        basketEstimate?.adjusted(toMonthlySpendCents: answers.spendAdjustment?.midpointCents)
            ?? (nil, nil, nil)
    }

    func resetBasketQuote() {
        basketTask?.cancel()
        basketTask = nil
        basketDelivered = false
        basketQuotes = []
        basketEstimate = nil
        basketFailed = false
        quoteStatuses = [:]
    }

    func retryBasketQuote() {
        resetBasketQuote()
        while let last = path.last, last == .basketResult || last == .planLoader {
            path.removeLast()
        }
        push(.planLoader)
    }

    func runBasketQuote() {
        guard basketTask == nil, !basketDelivered else { return }
        let stores = quotedStores
        quoteStatuses = Dictionary(uniqueKeysWithValues: stores.map { ($0, QuoteStatus.loading) })
        basketQuotes = []
        let service = basketService
        let postalCode = answers.postalCode.isEmpty ? nil : answers.postalCode
        let minimum = minimumLineDuration
        let hardCap = basketHardCap

        basketTask = Task { [weak self] in
            let clock = ContinuousClock()
            let startedAt = clock.now
            await withTaskGroup(of: (StoreChoice, BasketQuote?).self) { group in
                for store in stores {
                    guard let retailer = store.retailerID else { continue }
                    group.addTask {
                        let quote = await withTaskGroup(of: BasketQuote?.self) { inner in
                            inner.addTask {
                                try? await service.quoteBasket(retailer: retailer, postalCode: postalCode)
                            }
                            inner.addTask {
                                try? await Task.sleep(for: hardCap)
                                return nil
                            }
                            let first = await inner.next() ?? nil
                            inner.cancelAll()
                            return first
                        }
                        return (store, quote)
                    }
                }
                var revealed = 0
                for await (store, quote) in group {
                    revealed += 1
                    let due = startedAt.advanced(by: minimum * revealed)
                    if clock.now < due {
                        try? await clock.sleep(until: due)
                    }
                    guard !Task.isCancelled else { return }
                    if let quote {
                        self?.basketQuotes.append(quote)
                        self?.quoteStatuses[store] = .done
                    } else {
                        self?.quoteStatuses[store] = .failed
                    }
                }
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: minimum / 2)
            guard !Task.isCancelled else { return }
            self?.finishBasketQuote()
        }
    }

    private func finishBasketQuote() {
        basketTask = nil
        basketDelivered = true
        basketEstimate = BasketEstimate.make(
            quotes: basketQuotes,
            baseStore: answers.usualStore,
            comparisonStores: answers.orderedComparisonStores,
            householdSize: answers.householdSize,
            frequency: answers.shoppingFrequency
        )
        basketFailed = (basketEstimate?.comparableItemCount ?? 0) == 0
        if basketFailed {
            OnboardingEvent.basketFailed.log()
        } else {
            OnboardingEvent.basketQuoted(savingsCents: basketEstimate?.savingsMonthlyCents ?? 0).log()
        }
        if currentStep == .planLoader {
            advance(from: .planLoader)
        }
    }

    func requestNotificationAuthorizationIfNeeded() async {
        guard await notificationStatusProvider() == .notDetermined else { return }
        _ = await notificationAuthorizationRequester()
    }


    func makePaywallContext() -> PaywallContext {
        PaywallContext(
            basketSavingsMonthlyCents: displayedFigures.savings,
            householdLabel: answers.householdSize?.title,
            frequencyLabel: answers.shoppingFrequency?.title,
            postalCode: answers.postalCode.isEmpty ? nil : answers.postalCode,
            storesLabel: answers.orderedComparisonStores.isEmpty
                ? nil
                : StoreChoice.joinedTitles(answers.orderedComparisonStores),
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
            postalCode: answers.postalCode,
            profile: answers.profile
        )
        OnboardingEvent.finished.log()
        onFinished()
    }

    #if DEBUG
    func seedSampleAnswers() {
        answers.householdSize = .threeFour
        answers.shoppingFrequency = .weekly
        answers.usualStore = .walmart
        answers.comparisonStores = [.walmart, .bodegaAurrera, .chedraui]
        answers.postalCode = "06700"
        answers.importMethod = .paste
        answers.importedItems = MockFixtures.draft.items
        if ProcessInfo.processInfo.arguments.contains("-onboardingUnsupportedBase") {
            answers.usualStore = .soriana
            answers.comparisonStores = [.bodegaAurrera, .chedraui]
        }
    }
    #endif
}
