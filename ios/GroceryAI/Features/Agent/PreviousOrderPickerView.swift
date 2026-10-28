import SwiftUI

struct PreviousOrderPickerView: View {
    let orders: [CompletedOrder]
    let onAdd: ([ProductRequest]) -> Void

    var body: some View {
        Group {
            if orders.isEmpty {
                ContentUnavailableView(
                    "Sin compras anteriores",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Tus comparaciones guardadas aparecerán aquí.")
                )
            } else {
                List(orders) { order in
                    NavigationLink(value: order) {
                        OrderHistoryRow(order: order)
                    }
                }
            }
        }
        .navigationDestination(for: CompletedOrder.self) { order in
            PreviousOrderSelectionView(order: order, onAdd: onAdd)
        }
    }
}
