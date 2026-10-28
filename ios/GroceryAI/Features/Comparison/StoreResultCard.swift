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
                HStack(alignment: .center, spacing: AppSpacing.medium) {
                    RetailerLogo(
                        retailerID: store.retailerID ?? RetailerID(backendValue: nil, displayName: store.retailer),
                        retailerName: store.retailer
                    )

                    VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                        Text(store.retailer)
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

}
