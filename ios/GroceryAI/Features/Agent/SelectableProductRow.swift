import SwiftUI

struct SelectableProductRow: View {
    @Binding var item: SelectableProduct

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            Button(action: toggleSelection) {
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isSelected ? Color.accentColor : .secondary)

                    Text(item.product.name)
                        .font(.body)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.product.name), \(item.product.quantityDescription)")
            .accessibilityValue(item.isSelected ? "Seleccionado" : "No seleccionado")

            ProductQuantityControl(item: $item)
                .frame(maxWidth: 180)
                .opacity(item.isSelected ? 1 : 0)
                .allowsHitTesting(item.isSelected)
                .accessibilityHidden(!item.isSelected)
        }
        .padding(.vertical, AppSpacing.extraSmall)
    }

    private func toggleSelection() {
        item.isSelected.toggle()
    }
}
