import SwiftUI

struct UnmatchedItemsCard: View {
    let items: [UnmatchedItem]

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Label("Productos sin coincidencia", systemImage: "exclamationmark.triangle.fill")
                .font(.title3.bold())
                .foregroundStyle(colors.statusWarning)

            SurfaceCard {
                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                            Text(item.requestedItem.name)
                                .font(.headline)
                            Text(item.reason)
                                .font(.subheadline)
                                .foregroundStyle(colors.textSecondary)
                        }

                        if item.id != items.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
