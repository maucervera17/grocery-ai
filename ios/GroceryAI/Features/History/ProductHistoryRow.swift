import SwiftUI

struct ProductHistoryRow: View {
    let product: ProductRequest

    var body: some View {
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
        .accessibilityElement(children: .combine)
    }
}
