import SwiftUI

struct PaywallPlansPage: View {
    let subscriptionService: any SubscriptionServicing
    var dates: PaywallDates = .init()
    let onBack: () -> Void
    let onSubscribed: (SubscriptionPlanID) -> Void

    @State private var selectedPlanID: SubscriptionPlanID = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-paywallPlanMonthly") {
            return .monthly
        }
        #endif
        return .annual
    }()
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var alert: PaywallAlert?
    @State private var isAlertPresented = false

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        PaywallPageScaffold(onBack: onBack) {
            VStack(alignment: .leading, spacing: AppSpacing.extraLarge) {
                Text("Empieza gratis hoy")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                VStack(spacing: AppSpacing.medium) {
                    ForEach(plans) { plan in
                        PaywallPlanCard(
                            plan: plan,
                            isSelected: plan.id == selectedPlanID,
                            savingsPercent: savingsPercent(for: plan),
                            monthlyEquivalentCents: monthlyEquivalentCents(for: plan)
                        ) {
                            selectedPlanID = plan.id
                        }
                    }
                }
                .disabled(isBusy)

                if dynamicTypeSize.isAccessibilitySize {
                    cancellationNote(colors: colors)
                }

                summaryReceipt(colors: colors)

                legalLinks(colors: colors)
            }
        } footer: {
            VStack(spacing: AppSpacing.small) {
                GlassProminentButton(callToActionTitle, isLoading: isPurchasing, action: purchase)
                    .disabled(isRestoring)

                // In accessibility sizes the note moves into the scroll view so the
                // pinned footer stays short and never covers the billed price.
                if !dynamicTypeSize.isAccessibilitySize {
                    cancellationNote(colors: colors)
                }
            }
        }
        .alert(
            alert?.title ?? "",
            isPresented: $isAlertPresented,
            presenting: alert
        ) { _ in
            Button("Aceptar", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private var plans: [SubscriptionPlan] {
        subscriptionService.plans
    }

    private var selectedPlan: SubscriptionPlan? {
        plans.first { $0.id == selectedPlanID }
    }

    private var isBusy: Bool {
        isPurchasing || isRestoring
    }

    private var callToActionTitle: LocalizedStringKey {
        guard let plan = selectedPlan else { return "Suscribirme" }
        if let trialDays = plan.trialDays {
            return "Empezar mis \(trialDays) días gratis"
        }
        return "Suscribirme por \(DisplayPriceFormatter.string(cents: plan.priceCents)) al \(plan.periodName)"
    }

    private func summaryReceipt(colors: AppThemeColors) -> some View {
        let isAnnual = selectedPlanID == .annual
        let chargeLine = ReceiptView.Line(
            label: dates.formatted(dates.chargeDate),
            price: DisplayPriceFormatter.string(cents: selectedPlan?.priceCents ?? 0)
        )
        return ReceiptView(
            title: "Resumen",
            lines: isAnnual
                ? [.init(label: "Hoy", price: "$0.00"), chargeLine]
                : [.init(label: "Hoy", price: DisplayPriceFormatter.string(cents: selectedPlan?.priceCents ?? 0))],
            footerText: isAnnual
                ? "Renovación anual · Cancela cuando quieras"
                : "Renovación mensual · Cancela cuando quieras"
        )
        .contentTransition(.numericText())
        .animation(.smooth, value: selectedPlanID)
    }

    private func present(_ newAlert: PaywallAlert) {
        alert = newAlert
        isAlertPresented = true
    }

    private func cancellationNote(colors: AppThemeColors) -> some View {
        Label(
            selectedPlanID == .annual
                ? "Sin pago hoy · Cancela en Ajustes cuando quieras"
                : "Cancela en Ajustes cuando quieras",
            systemImage: "checkmark.shield"
        )
        .font(.footnote)
        .foregroundStyle(colors.textSecondary)
        .frame(maxWidth: .infinity)
    }

    private func legalLinks(colors: AppThemeColors) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppSpacing.small) {
                legalLinkButtons(separator: true, colors: colors)
            }
            VStack(spacing: 0) {
                legalLinkButtons(separator: false, colors: colors)
            }
        }
        .font(.subheadline.weight(.medium))
        .tint(colors.brandPrimary)
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppSpacing.section)
    }

    @ViewBuilder
    private func legalLinkButtons(separator: Bool, colors: AppThemeColors) -> some View {
        Button("Restaurar compras", action: restore)
            .disabled(isBusy)
            .frame(minHeight: AppControlSize.minimumTapTarget)
        if separator {
            Text("·").foregroundStyle(colors.textSecondary).accessibilityHidden(true)
        }
        Link("Términos", destination: LegalLinks.terms)
            .frame(minHeight: AppControlSize.minimumTapTarget)
        if separator {
            Text("·").foregroundStyle(colors.textSecondary).accessibilityHidden(true)
        }
        Link("Privacidad", destination: LegalLinks.privacy)
            .frame(minHeight: AppControlSize.minimumTapTarget)
    }

    private func renewalDisclosure(for plan: SubscriptionPlan) -> String {
        let price = DisplayPriceFormatter.string(cents: plan.priceCents)
        if plan.trialDays != nil {
            return "Después \(price) al \(plan.periodName). Cancela cuando quieras."
        }
        return "\(price) al \(plan.periodName). Cancela cuando quieras."
    }

    private func savingsPercent(for plan: SubscriptionPlan) -> Int? {
        guard plan.id == .annual,
              let monthly = plans.first(where: { $0.id == .monthly }),
              monthly.priceCents > 0 else {
            return nil
        }
        let yearlyAtMonthlyPrice = Double(monthly.priceCents * 12)
        let savings = (yearlyAtMonthlyPrice - Double(plan.priceCents)) / yearlyAtMonthlyPrice
        return Int((savings * 100).rounded())
    }

    private func monthlyEquivalentCents(for plan: SubscriptionPlan) -> Int? {
        guard plan.id == .annual else {
            return nil
        }
        // Whole pesos, like every other price on the paywall.
        return Int((Double(plan.priceCents) / 1_200).rounded()) * 100
    }

    private func purchase() {
        let planID = selectedPlanID
        isPurchasing = true
        Task {
            defer { isPurchasing = false }
            do {
                try await subscriptionService.purchase(planID)
                onSubscribed(planID)
            } catch is CancellationError {
                return
            } catch {
                present(.purchaseFailed(message: error.localizedDescription))
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                if try await subscriptionService.restore() {
                    onSubscribed(.annual)
                } else {
                    present(.noPurchasesFound)
                }
            } catch is CancellationError {
                return
            } catch {
                present(.restoreFailed(message: error.localizedDescription))
            }
        }
    }
}

#Preview("Planes") {
    PaywallPlansPage(
        subscriptionService: PlaceholderSubscriptionService(
            defaults: UserDefaults(suiteName: "barasu.paywall.preview") ?? .standard
        ),
        onBack: {},
        onSubscribed: { _ in }
    )
}

#Preview("Planes oscuro") {
    PaywallPlansPage(
        subscriptionService: PlaceholderSubscriptionService(
            defaults: UserDefaults(suiteName: "barasu.paywall.preview") ?? .standard
        ),
        onBack: {},
        onSubscribed: { _ in }
    )
    .preferredColorScheme(.dark)
}
