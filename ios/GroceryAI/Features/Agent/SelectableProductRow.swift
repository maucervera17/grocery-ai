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

                    VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                        Text(item.product.name)
                            .font(.body)
                        Text(item.product.quantityDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.product.name), \(item.product.quantityDescription)")
            .accessibilityValue(item.isSelected ? "Seleccionado" : "No seleccionado")

            if item.isSelected {
                Stepper(
                    value: $item.product.quantity,
                    in: item.quantityStep...maximumQuantity,
                    step: item.quantityStep
                ) {
                    Text("Cantidad de \(item.product.name)")
                }
                .labelsHidden()
                .accessibilityValue(item.product.quantityDescription)
            }
        }
        .padding(.vertical, AppSpacing.extraSmall)
    }

    private var maximumQuantity: Double {
        switch item.product.unit {
        case .gram, .milliliter:
            10_000
        default:
            100
        }
    }

    private func toggleSelection() {
        item.isSelected.toggle()
    }
}
