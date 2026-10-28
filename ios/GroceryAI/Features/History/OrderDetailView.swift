import SwiftUI

struct OrderDetailView: View {
    let order: CompletedOrder
    let onRepeat: (CompletedOrder) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppSpacing.large) {
                summaryCard

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text("Productos solicitados")
                        .font(.title3.bold())

                    SurfaceCard {
                        VStack(spacing: AppSpacing.medium) {
                            ForEach(order.requestedItems) { item in
                                ProductHistoryRow(product: item)

                                if item.id != order.requestedItems.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    Text("Distribución por tienda")
                        .font(.title3.bold())

                    ForEach(order.stores) { store in
                        StoreResultCard(store: store, currencyCode: order.currencyCode)
                    }
                }

                PrimaryButton("Repetir compra", systemImage: "arrow.clockwise") {
                    onRepeat(order)
                }
            }
            .padding(AppSpacing.large)
        }
        .navigationTitle("Compra anterior")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(order.completedAt.formatted(date: .long, time: .omitted))
                    .font(.headline)

                Text(MoneyFormatter.string(cents: order.totalPriceCents, currencyCode: order.currencyCode))
                    .font(.largeTitle.bold())

                Text("\(order.stores.count) tiendas · No incluye transporte ni entrega")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    NavigationStack {
        OrderDetailView(order: MockFixtures.completedOrder, onRepeat: { _ in })
    }
}
