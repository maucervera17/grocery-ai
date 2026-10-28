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
                Button {
                    selectedOrder = order
                } label: {
                    SurfaceCard(padding: AppSpacing.medium) {
                        HStack(spacing: AppSpacing.medium) {
                            OrderHistoryRow(order: order)

                            Image(systemName: "chevron.right")
                                .font(.footnote.bold())
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(.rect)
                .accessibilityHint("Abre el detalle de la compra")
                .accessibilityAction(named: "Repetir compra") {
                    onRepeatOrder(order)
                }
                .swipeActions(edge: .trailing) {
                    Button("Repetir", systemImage: "arrow.clockwise") {
                        onRepeatOrder(order)
                    }
                    .tint(BarasuPalette.accent)
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
