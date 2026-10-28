import SwiftUI

struct OrderHistoryRow: View {
    let order: CompletedOrder

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "bag.fill")
                .font(.title2)
                .foregroundStyle(colors.brandPrimary)
                .frame(width: 48, height: 48)
                .background(colors.brandSecondary, in: .rect(cornerRadius: AppRadius.medium))
                .accessibilityHidden(true)

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
