import SwiftUI

struct FrequentProductCard: View {
    @Binding var item: SelectableProduct

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Button(action: toggleSelection) {
                VStack(spacing: AppSpacing.small) {
                    ZStack(alignment: .topTrailing) {
                        ProductThumbnail(
                            imageURL: item.imageURL,
                            category: item.product.categoryID ?? .inferred(from: item.product.name),
                            size: 64
                        )
                            .frame(maxWidth: .infinity)

                        Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(item.isSelected ? colors.brandPrimary : colors.textSecondary)
                            .background(.background, in: .circle)
                    }

                    Text(item.product.name)
                        .font(.headline)
                        .lineLimit(1)

                }
                .frame(maxWidth: .infinity)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.product.name), \(item.product.quantityDescription)")
            .accessibilityValue(item.isSelected ? "Seleccionado" : "No seleccionado")

            ProductQuantityControl(item: $item)
                .opacity(item.isSelected ? 1 : 0)
                .allowsHitTesting(item.isSelected)
                .accessibilityHidden(!item.isSelected)
        }
        .padding(AppSpacing.medium)
        .frame(width: 190)
        .background(colors.surfacePrimary, in: .rect(cornerRadius: AppRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(item.isSelected ? colors.brandPrimary : colors.borderSubtle, lineWidth: item.isSelected ? 2 : 1)
        }
        .animation(.smooth, value: item.isSelected)
    }

    private var colors: AppThemeColors {
        theme.colors(for: colorScheme)
    }

    private func toggleSelection() {
        item.isSelected.toggle()
    }
}
