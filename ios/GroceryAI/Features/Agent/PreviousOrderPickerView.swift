import SwiftUI

struct PreviousOrderPickerView: View {
    let orders: [CompletedOrder]
    let searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("Compras anteriores")
                .font(.title3.bold())

            if filteredOrders.isEmpty {
                Text(searchText.isEmpty ? "Tus comparaciones guardadas aparecerán aquí." : "No hay compras anteriores que coincidan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.large)
            } else {
                ForEach(filteredOrders) { order in
                    NavigationLink(value: order) {
                        SurfaceCard(padding: AppSpacing.medium) {
                            HStack(spacing: AppSpacing.medium) {
                                OrderArtwork(order: order)

                                VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                                    Text(order.completedAt.formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                    Text("\(order.requestedItems.count) productos")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(productSummary(for: order))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .contentShape(.rect)
                    .accessibilityHint("Abre los productos de esta compra")
                }
            }
        }
        .id(AddContentSection.orders)
    }

    private var filteredOrders: [CompletedOrder] {
        guard !searchText.isEmpty else { return orders }
        return orders.filter { order in
            order.requestedItems.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
                || order.completedAt.formatted(date: .abbreviated, time: .omitted)
                    .localizedCaseInsensitiveContains(searchText)
        }
    }

    private func productSummary(for order: CompletedOrder) -> String {
        let names = order.requestedItems.prefix(3).map(\.name)
        let remaining = order.requestedItems.count - names.count
        return remaining > 0
            ? names.joined(separator: ", ") + " y \(remaining) más"
            : names.joined(separator: ", ")
    }
}
