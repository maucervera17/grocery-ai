import SwiftUI

struct OrderHistoryList: View {
    let orders: [CompletedOrder]
    let isSearching: Bool
    let onRepeatOrder: (CompletedOrder) -> Void

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
                        NavigationLink {
                            OrderDetailView(order: order, onRepeat: onRepeatOrder)
                        } label: {
                            OrderHistoryRow(order: order)
                        }
                        .buttonStyle(.plain)

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
        }
    }
}
