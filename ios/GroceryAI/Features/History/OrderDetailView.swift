import SwiftUI

struct OrderDetailView: View {
    let order: CompletedOrder
    let onRepeat: (CompletedOrder) -> Void

    @State private var repeatOverlayHeight: CGFloat = 0

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
                                ProductHistoryRow(
                                    product: item,
                                    imageURL: imageURL(for: item)
                                )

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

            }
            .padding(AppSpacing.large)
        }
        .contentMargins(.bottom, repeatOverlayHeight, for: .scrollContent)
        .overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                BottomContentFade()
                    .frame(height: repeatOverlayHeight + AppControlSize.bottomContentFadeExtension)
                    .ignoresSafeArea(edges: .bottom)

                RepeatOrderOverlay(action: repeatOrder)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        repeatOverlayHeight = height
                    }
            }
        }
        .navigationTitle("Compra anterior")
        .toolbarTitleDisplayMode(.inline)
    }

    private func repeatOrder() {
        onRepeat(order)
    }

    private func imageURL(for product: ProductRequest) -> URL? {
        order.stores
            .lazy
            .flatMap(\.items)
            .first(where: { $0.clientItemID == product.id })?
            .imageURL
    }

    private var summaryCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.small) {
                Text(order.completedAt.formatted(date: .long, time: .omitted))
                    .font(.headline)

                Text(MoneyFormatter.string(cents: order.totalPriceCents, currencyCode: order.currencyCode))
                    .font(.largeTitle.bold())

                Label("\(order.stores.count) tiendas", systemImage: "storefront")
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
