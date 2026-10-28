import SwiftUI

struct ComparisonResultView: View {
    let plan: ComparisonPlan
    let onDone: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(plan: ComparisonPlan, onDone: @escaping () -> Void = {}) {
        self.plan = plan
        self.onDone = onDone
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.extraLarge) {
                ComparisonSummaryCard(plan: plan)
                ForEach(Array((plan.warnings ?? []).enumerated()), id: \.offset) { _, warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text("Tiendas")
                        .font(.title2.bold())

                    MatchStatusLegend()

                    ForEach(plan.stores) { store in
                        StoreResultCard(store: store, currencyCode: plan.currencyCode)
                    }
                }

                if !plan.unmatchedItems.isEmpty {
                    UnmatchedItemsCard(items: plan.unmatchedItems)
                }

                Label("Precios estimados; entrega no incluida", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)

                if plan.responseStatus != .partial && plan.responseStatus != .error {
                    PrimaryButton("Guardar y terminar", systemImage: "checkmark") { onDone() }
                }
            }
            .padding(AppSpacing.large)
        }
        .background(colors.backgroundPrimary)
        .navigationTitle("Comparación")
        .toolbarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ComparisonResultView(plan: MockFixtures.comparisonPlan)
    }
}
