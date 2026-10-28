import SwiftUI

struct PreviousOrderPickerView: View {
    let orders: [CompletedOrder]
    let onSelect: (CompletedOrder) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
                        } label: {
                            OrderHistoryRow(order: order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Compra anterior")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
