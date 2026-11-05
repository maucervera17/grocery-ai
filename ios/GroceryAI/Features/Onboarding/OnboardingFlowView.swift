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
                comparisonService: MockComparisonService()
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

        case .intro:
            IntroStep(
                onContinue: { model.advance(from: .intro) },
                onBack: model.goBack
            )

        case .householdSize:
            QuestionStep(
                step: step,
                title: "¿Para cuántas personas compras?",
                subtitle: "Lo usamos para estimar tu ahorro.",
                options: HouseholdSize.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                hasSelection: model.answers.householdSize != nil,
                isSelected: { model.answers.householdSize == $0 },
                onSelect: { model.select($0) },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .frequency:
            QuestionStep(
                step: step,
                title: "¿Cada cuánto haces el súper?",
                subtitle: "Lo usamos para ajustar los recordatorios.",
                options: ShoppingFrequency.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                hasSelection: model.answers.shoppingFrequency != nil,
                isSelected: { model.answers.shoppingFrequency == $0 },
                onSelect: { model.select($0) },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .monthlySpend:
            QuestionStep(
                step: step,
                title: "¿Cuánto gastas al mes en el súper?",
                subtitle: "Un hogar en México gasta en promedio unos $6,000 al mes en alimentos y bebidas (INEGI).",
                options: SpendRange.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                hasSelection: model.answers.monthlySpend != nil,
                isSelected: { model.answers.monthlySpend == $0 },
                onSelect: { model.select($0) },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .usualStores:
            QuestionStep(
                step: step,
                title: "¿Dónde compras normalmente?",
                subtitle: "Puedes elegir varias. Lo usamos para personalizar tu comparación.",
                options: StoreChoice.allCases.map {
                    .init(
                        value: $0,
                        title: $0.title,
                        systemImage: $0 == .mercado ? "basket" : $0 == .other ? "ellipsis.circle" : nil,
                        logoAssetName: $0.logoAssetName
                    )
                },
                allowsMultipleSelection: true,
                hasSelection: !model.answers.usualStores.isEmpty,
                isSelected: { model.answers.usualStores.contains($0) },
                onSelect: { model.toggle($0) },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .compareHabit:
            QuestionStep(
                step: step,
                title: "¿Comparas precios antes de comprar?",
                subtitle: "Lo usamos para personalizar tu experiencia.",
                options: CompareHabit.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                hasSelection: model.answers.comparesToday != nil,
                isSelected: { model.answers.comparesToday == $0 },
                onSelect: { model.select($0) },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .insight:
            InsightStep(
                habit: model.answers.comparesToday,
                onContinue: { model.advance(from: .insight) },
                onBack: model.goBack
            )

        case .goals:
            QuestionStep(
                step: step,
                title: "¿Qué es lo más importante para ti?",
                subtitle: "Elige hasta 2. Ordenamos los beneficios con tu respuesta.",
                options: ShoppingGoal.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                allowsMultipleSelection: true,
                hasSelection: !model.answers.goals.isEmpty,
                isSelected: { model.answers.goals.contains($0) },
                onSelect: { model.toggle($0) },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .painPoints:
            QuestionStep(
                step: step,
                title: "¿Qué es lo más difícil del súper?",
                subtitle: "Puedes elegir varias.",
                options: PainPoint.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                allowsMultipleSelection: true,
                hasSelection: !model.answers.painPoints.isEmpty,
                isSelected: { model.answers.painPoints.contains($0) },
                onSelect: { model.toggle($0) },
                onContinue: { model.advance(from: step) },
                onBack: model.goBack
            )

        case .listHabit:
            QuestionStep(
                step: step,
                title: "¿Cómo haces tu lista hoy?",
                subtitle: "Te recomendaremos la forma más fácil de traerla.",
                options: ListHabit.allCases.map {
                    .init(value: $0, title: $0.title, systemImage: $0.systemImage)
                },
                hasSelection: model.answers.listHabit != nil,
                isSelected: { model.answers.listHabit == $0 },
                onSelect: { model.select($0) },
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

        case .planLoader:
            PlanLoaderStep(
                answers: model.answers,
                onFinished: { model.advance(from: .planLoader) },
                warmUp: model.warmUpBackend
            )

        case .savingsResult:
            SavingsResultStep(
                answers: model.answers,
                estimate: model.savingsEstimate,
                onContinue: { model.advance(from: .savingsResult) }
            )

        case .benefits:
            BenefitsStep(
                answers: model.answers,
                onContinue: { model.advance(from: .benefits) },
                onBack: model.goBack
            )

        case .access:
            AccessStep(model: model, onBack: model.goBack)

        case .importMethod:
            ImportMethodStep(model: model, onBack: model.goBack)

        case .importReview:
            ImportReviewStep(model: model, onBack: model.goBack)

        case .demoPick:
            DemoPickStep(model: model, onBack: model.goBack)

        case .demoComparing:
            DemoComparingStep(model: model)

        case .demoResult:
            DemoResultStep(model: model)

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
