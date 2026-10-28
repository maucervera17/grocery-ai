import SwiftUI

struct OrderHistoryRow: View {
    let order: CompletedOrder

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(order.completedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)

                Spacer()

                Text(MoneyFormatter.string(cents: order.totalPriceCents, currencyCode: order.currencyCode))
                    .font(.headline)
            }

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppSpacing.extraSmall)
    }

    private var summary: String {
        "\(order.requestedItems.count) productos · \(order.stores.count) tiendas"
    }
}
