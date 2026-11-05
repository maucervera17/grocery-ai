import SwiftUI

struct DemoResultStep: View {
    let model: OnboardingModel
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    private var receiptLines: [ReceiptView.Line] {
        guard let plan = model.demoPlan else { return [] }
        return plan.stores.flatMap { store in
            store.items.map { line in
                ReceiptView.Line(
                    label: line.productName,
                    secondary: store.retailer,
                    price: DisplayPriceFormatter.string(cents: line.lineTotalCents),
                    logoAssetName: logoAsset(for: store)
                )
            }
        }
    }

    private var unmatched: [UnmatchedItem] {
        model.demoPlan?.unmatchedItems ?? []
    }

    private func logoAsset(for store: StorePlan) -> String? {
        switch store.retailerID {
        case .walmart: "RetailerWalmart"
        case .bodegaAurrera: "RetailerBodegaAurrera"
        case .chedraui: "RetailerChedraui"
        default: nil
        }
    }

    private var matchedCount: Int {
        model.demoPlan?.stores.reduce(0) { $0 + $1.items.count } ?? 0
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .demoResult,
            onBack: onBack,
            layout: .centered,
            footer: {
            GlassProminentButton(model.accessSkipped && model.demoPlan == nil ? "Continuar" : "Comparar mi lista completa") {
                model.advance(from: .demoResult)
            }
            },
            content: {
            if model.accessSkipped && model.demoPlan == nil {
                VStack(spacing: AppSpacing.large) {
                    Image(systemName: "lock")
                        .font(.largeTitle)
                        .foregroundStyle(colors.textSecondary)
                        .accessibilityHidden(true)
                    VStack(spacing: AppSpacing.small) {
                        Text("Comparar precios requiere acceso")
                            .font(.headline)
                            .foregroundStyle(colors.textPrimary)
                            .multilineTextAlignment(.center)
                        Text("Barasu está en acceso anticipado. Tu lista queda guardada; cuando tengas tu contraseña, agrégala en Ajustes para ver precios reales.")
                            .font(.body)
                            .foregroundStyle(colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            } else if model.demoFailed {
                VStack(spacing: AppSpacing.large) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.largeTitle)
                        .foregroundStyle(colors.textSecondary)
                        .accessibilityHidden(true)
                    VStack(spacing: AppSpacing.small) {
                        Text("No pudimos consultar precios ahora")
                            .font(.headline)
                            .foregroundStyle(colors.textPrimary)
                        Text("Tu lista queda lista para comparar cuando quieras")
                            .font(.body)
                            .foregroundStyle(colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            } else if let plan = model.demoPlan {
                VStack(alignment: .leading, spacing: AppSpacing.large) {
                    headline(plan: plan, colors: colors)

                    ReceiptView(
                        title: "Tu prueba",
                        lines: receiptLines,
                        totalLabel: "Total",
                        totalPrice: DisplayPriceFormatter.string(cents: plan.totalPriceCents)
                    )

                    if let savings = plan.estimatedSavingsCents, savings > 0 {
                        Text("−\(DisplayPriceFormatter.string(cents: savings)) vs. comprar todo en una sola tienda")
                            .font(.subheadline.weight(.semibold))
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(colors.statusSuccess)
                    }

                    if !unmatched.isEmpty {
                        ForEach(unmatched) { item in
                            Label("\(item.requestedItem.name): sin coincidencia", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(colors.statusWarning)
                        }
                    }

                    let remaining = model.answers.importedItems.count - matchedCount
                    if remaining > 0 {
                        Text("Tu lista tiene \(remaining) productos más")
                            .font(.callout)
                            .foregroundStyle(colors.textSecondary)
                    }

                    Text("Precios publicados; confirma en tienda")
                        .font(.caption)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            }
        )
        .sensoryFeedback(.success, trigger: model.demoPlan != nil)
    }

    @ViewBuilder
    private func headline(plan: ComparisonPlan, colors: AppThemeColors) -> some View {
        if let savings = plan.estimatedSavingsCents, savings > 0 {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ahorras \(DisplayPriceFormatter.string(cents: savings))")
                    .font(.title.weight(.semibold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(colors.textPrimary)
                Text("en \(matchedCount) productos")
                    .font(AppTypography.body)
                    .foregroundStyle(colors.textSecondary)
            }
        } else {
            Text("Tu tienda habitual ya es la más barata en estos productos")
                .font(.headline)
                .foregroundStyle(colors.textPrimary)
        }
    }
}
