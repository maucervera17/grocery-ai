import SwiftUI

struct StoreResultCard: View {
    let store: StorePlan
    let currencyCode: String

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.large) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                        Text(displayRetailer)
                            .font(.headline)

                        if let storeName = store.storeName, !storeName.isEmpty {
                            Text(storeName)
                                .font(.caption)
                                .foregroundStyle(colors.textSecondary)
                        }
                    }

                    Spacer()

                    Text(MoneyFormatter.string(cents: store.subtotalCents, currencyCode: currencyCode))
                        .font(.headline)
                }

                Divider()

                ForEach(store.items) { item in
                    StorePlanItemRow(item: item, currencyCode: currencyCode)

                    if item.id != store.items.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var displayRetailer: String {
        store.retailer.replacingOccurrences(
            of: " (demo)",
            with: "",
            options: .caseInsensitive
        )
    }
}
