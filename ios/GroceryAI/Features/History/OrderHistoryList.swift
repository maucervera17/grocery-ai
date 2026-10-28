import SwiftUI

struct OrderHistoryList: View {
    let orders: [CompletedOrder]
    let isSearching: Bool
    let onRepeatOrder: (CompletedOrder) -> Void

    @State private var selectedOrder: CompletedOrder?

    var body: some View {
        if orders.isEmpty {
            if isSearching {
                ContentUnavailableView.search
            } else {
                ContentUnavailableView(
                    "Sin compras anteriores",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Las comparaciones completadas aparecerán aquí.")
                )
            }
        } else {
            List(orders) { order in
                SurfaceCard(padding: AppSpacing.medium) {
                    HStack(spacing: AppSpacing.medium) {
                        Button {
                            selectedOrder = order
                        } label: {
                            OrderHistoryRow(order: order)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Abre el detalle de la compra")

                        Button("Repetir") {
                            onRepeatOrder(order)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: AppRadius.medium))
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: AppSpacing.small,
                    leading: AppSpacing.large,
                    bottom: AppSpacing.small,
                    trailing: AppSpacing.large
                ))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationDestination(item: $selectedOrder) { order in
                OrderDetailView(order: order, onRepeat: onRepeatOrder)
            }
        }
    }
}
