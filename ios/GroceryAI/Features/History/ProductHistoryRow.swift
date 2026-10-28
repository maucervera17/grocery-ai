import SwiftUI

struct ProductHistoryRow: View {
    let product: ProductRequest

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(spacing: AppSpacing.medium) {
            Image(systemName: "cart")
                .frame(width: 28)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                Text(product.name)
                    .font(.body)

                if let notes = product.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(ProductQuantityFormatter.string(quantity: product.quantity, unit: product.unit))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: AppControlSize.minimumTapTarget, alignment: .leading)
        .background(colors.cellBackground, in: .rect(cornerRadius: AppRadius.medium))
        .accessibilityElement(children: .combine)
    }
}
