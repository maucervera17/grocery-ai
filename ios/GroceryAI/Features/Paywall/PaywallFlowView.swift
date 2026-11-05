import SwiftUI

struct PaywallFlowView: View {
    private enum Page: Int, Comparable {
        case value
        case trial
        case plans

        static func < (lhs: Page, rhs: Page) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private let context: PaywallContext
    private let subscriptionService: any SubscriptionServicing
    private let onSubscribed: (SubscriptionPlanID) -> Void

    @State private var page: Page = .value
    @State private var isMovingForward = true

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        context: PaywallContext,
        subscriptionService: any SubscriptionServicing,
        onSubscribed: @escaping (SubscriptionPlanID) -> Void
    ) {
        self.context = context
        self.subscriptionService = subscriptionService
        self.onSubscribed = onSubscribed
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        ZStack {
            switch page {
            case .value:
                PaywallValuePage(context: context) {
                    show(.trial)
                }
                .transition(pageTransition)
            case .trial:
                PaywallTrialPage(
                    annualPriceText: annualPriceText,
                    dates: dates,
                    onBack: { show(.value) },
                    onContinue: { show(.plans) }
                )
                .transition(pageTransition)
            case .plans:
                PaywallPlansPage(
                    subscriptionService: subscriptionService,
                    dates: dates,
                    onBack: { show(.trial) },
                    onSubscribed: onSubscribed
                )
                .transition(pageTransition)
            }
        }
        .background(colors.backgroundPrimary.ignoresSafeArea())
    }

    var dates: PaywallDates = .init()

    private var annualPriceText: String {
        let annual = subscriptionService.plans.first { $0.id == .annual }
        return DisplayPriceFormatter.string(cents: annual?.priceCents ?? 0)
    }

    private var pageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .push(from: isMovingForward ? .trailing : .leading)
    }

    private func show(_ destination: Page) {
        let movesForward = destination > page
        guard movesForward != isMovingForward else {
            animate(to: destination)
            return
        }
        isMovingForward = movesForward
        Task { @MainActor in
            await Task.yield()
            animate(to: destination)
        }
    }

    private func animate(to destination: Page) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth) {
            page = destination
        }
    }
}

#Preview("Paywall") {
    PaywallFlowView(
        context: .preview,
        subscriptionService: PlaceholderSubscriptionService(
            defaults: UserDefaults(suiteName: "barasu.paywall.preview") ?? .standard
        ),
        onSubscribed: { _ in }
    )
}

#Preview("Paywall oscuro") {
    PaywallFlowView(
        context: .preview,
        subscriptionService: PlaceholderSubscriptionService(
            defaults: UserDefaults(suiteName: "barasu.paywall.preview") ?? .standard
        ),
        onSubscribed: { _ in }
    )
    .preferredColorScheme(.dark)
}
