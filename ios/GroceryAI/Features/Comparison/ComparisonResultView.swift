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

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text("Plan por supermercado")
                        .font(.title2.bold())

                    ForEach(plan.stores) { store in
                        StoreResultCard(store: store, currencyCode: plan.currencyCode)
                    }
                }

                if !plan.unmatchedItems.isEmpty {
                    UnmatchedItemsCard(items: plan.unmatchedItems)
                }

                Text("Los precios son estimados y no incluyen transporte ni entrega.")
                    .font(.footnote)
                    .foregroundStyle(colors.textSecondary)

                PrimaryButton("Guardar y terminar", systemImage: "checkmark") {
                    onDone()
                }
            }
            .padding(AppSpacing.large)
        }
        .background(colors.backgroundPrimary)
        .navigationTitle("Comparación")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ComparisonResultView(plan: MockFixtures.comparisonPlan)
    }
}
