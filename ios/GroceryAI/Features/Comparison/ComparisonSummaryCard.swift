import SwiftUI

struct ComparisonSummaryCard: View {
    let plan: ComparisonPlan

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                Label("Mejor combinación estimada", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(colors.statusSuccess)

                Text(MoneyFormatter.string(cents: plan.totalPriceCents, currencyCode: plan.currencyCode))
                    .font(.largeTitle.bold())
                    .foregroundStyle(colors.textPrimary)

                HStack(spacing: AppSpacing.large) {
                    Label("\(plan.stores.count) tiendas", systemImage: "storefront")

                    if let savings = plan.estimatedSavingsCents {
                        Label(
                            "Ahorras \(MoneyFormatter.string(cents: savings, currencyCode: plan.currencyCode))",
                            systemImage: "tag"
                        )
                    }
                }
                .font(.subheadline)
                .foregroundStyle(colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
