import SwiftUI

struct OnboardingFlowView: View {
    @State private var model: OnboardingModel
    private let appState: AppState
    private let subscriptionService: any SubscriptionServicing
    private let onFinished: () -> Void

    init(
        appState: AppState,
        subscriptionService: any SubscriptionServicing,
        onFinished: @escaping () -> Void
    ) {
        self.appState = appState
        self.subscriptionService = subscriptionService
        self.onFinished = onFinished

        var model = OnboardingModel()
        #if DEBUG
        if Self.debugOnboardingStep != nil {
            model = OnboardingModel(
                agentService: MockAgentService(),
                basketService: MockBasketService()
            )
            model.seedSampleAnswers()
            model.notificationStatusProvider = { .notDetermined }
        }
        #endif
        #if DEBUG
        if let step = Self.debugOnboardingStep {
            model.path = [step]
        }
        #endif
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack(path: $model.path) {
            stepView(for: .welcome)
                .navigationDestination(for: OnboardingStep.self) { step in
                    stepView(for: step)
                        .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStep {
                model.advance(from: .welcome)
            }

        case .householdSize:
            QuestionStep(
                step: step,
                title: "¿Para cuántas personas compras?",
                subtitle: "Así calculamos cuánto lleva tu canasta.",
                options: HouseholdSize.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                hasSelection: model.answers.householdSize != nil,
                isSelected: { model.answers.householdSize == $0 },
                onSelect: {
                    model.select($0)
                    model.autoAdvance(from: step)
                },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .frequency:
            QuestionStep(
                step: step,
                title: "¿Cada cuánto haces el súper?",
                subtitle: "Con esto calculamos tu gasto al mes.",
                options: ShoppingFrequency.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                hasSelection: model.answers.shoppingFrequency != nil,
                isSelected: { model.answers.shoppingFrequency == $0 },
                onSelect: {
                    model.select($0)
                    model.autoAdvance(from: step)
                },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .usualStore:
            QuestionStep(
                step: step,
                title: "¿Dónde compras normalmente?",
                subtitle: "Elige una. Es la base para calcular cuánto gastas.",
                options: StoreChoice.allCases.map {
                    .init(
                        value: $0,
                        title: $0.title,
                        systemImage: $0.systemImage,
                        logoAssetName: $0.logoAssetName,
                        detail: $0.isSupportedByBarasu ? nil : "Aún no tenemos sus precios"
                    )
                },
                hasSelection: model.answers.usualStore != nil,
                isSelected: { model.answers.usualStore == $0 },
                onSelect: {
                    model.selectUsualStore($0)
                    model.autoAdvance(from: step)
                },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .postalCode:
            PostalCodeStep(
                postalCode: $model.answers.postalCode,
                onContinue: { code in
                    model.answers.postalCode = code
                    OnboardingEvent.answer(step: .postalCode, value: code).log()
                    model.advance(from: .postalCode)
                },
                onSkip: model.skipPostalCode,
                onBack: model.goBack
            )

        case .comparisonStores:
            ComparisonStoresStep(model: model, onBack: model.goBack)

        case .planLoader:
            PlanLoaderStep(model: model)

        case .basketResult:
            BasketResultStep(model: model) {
                if model.accessSkipped {
                    model.applySuggestedList()
                }
                model.advance(from: .basketResult)
            }

        case .access:
            AccessStep(model: model, onBack: model.goBack)

        case .importMethod:
            ImportMethodStep(model: model, onBack: model.goBack)

        case .importReview:
            ImportReviewStep(model: model, onBack: model.goBack)

        case .paywall:
            #if DEBUG
            if Self.debugPaywallPage == "trial" {
                PaywallTrialPage(
                    annualPriceText: DisplayPriceFormatter.string(
                        cents: subscriptionService.plans.first { $0.id == .annual }?.priceCents ?? 0
                    ),
                    onBack: {},
                    onContinue: {}
                )
                .navigationBarBackButtonHidden(true)
            } else if Self.debugPaywallPage == "plans" {
                PaywallPlansPage(
                    subscriptionService: subscriptionService,
                    onBack: {},
                    onSubscribed: { plan in
                        model.handleSubscribed(
                            plan: plan,
                            appState: appState,
                            onFinished: onFinished
                        )
                    }
                )
                .interactiveDismissDisabled()
                .navigationBarBackButtonHidden(true)
            } else {
                paywallView
            }
            #else
            paywallView
            #endif
        }
    }

    @ViewBuilder
    private var paywallView: some View {
        PaywallFlowView(
            context: model.makePaywallContext(),
            subscriptionService: subscriptionService
        ) { plan in
            model.handleSubscribed(
                plan: plan,
                appState: appState,
                onFinished: onFinished
            )
        }
        .interactiveDismissDisabled()
        .navigationBarBackButtonHidden(true)
    }

    #if DEBUG
    static var debugPaywallPage: String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-paywallPage"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    static var debugOnboardingStep: OnboardingStep? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-onboardingStep"),
              arguments.indices.contains(index + 1) else {
            return nil
        }
        return OnboardingStep(rawValue: arguments[index + 1])
    }
    #endif
}
