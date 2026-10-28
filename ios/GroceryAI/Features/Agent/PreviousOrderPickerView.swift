import SwiftUI

struct PreviousOrderPickerView: View {
    let orders: [CompletedOrder]
    let onSelect: (CompletedOrder) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if orders.isEmpty {
                EmptyStateView(
                    title: "Sin compras anteriores",
                    systemImage: "clock.arrow.circlepath",
                    message: "Tus comparaciones guardadas aparecerán aquí."
                )
            } else {
                List(orders) { order in
                    Button {
                        onSelect(order)
                        dismiss()
                    } label: {
                        OrderHistoryRow(order: order)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Compras anteriores")
        .toolbarTitleDisplayMode(.inline)
    }
}
