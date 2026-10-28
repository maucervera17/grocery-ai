import SwiftUI

struct OrderHistoryRow: View {
    let order: CompletedOrder

    var body: some View {
        HStack(spacing: AppSpacing.medium) {
            OrderArtwork(order: order)

            VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                Text(order.completedAt.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.headline)

                Text("\(order.requestedItems.count) productos")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(MoneyFormatter.string(cents: order.totalPriceCents, currencyCode: order.currencyCode))
                    .font(.title3.bold())

                Text(productSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var productSummary: String {
        let names = order.requestedItems.prefix(3).map(\.name)
        let remaining = order.requestedItems.count - names.count
        if remaining > 0 {
            return names.joined(separator: ", ") + " y \(remaining) más"
        }
        return names.joined(separator: ", ")
    }
}
