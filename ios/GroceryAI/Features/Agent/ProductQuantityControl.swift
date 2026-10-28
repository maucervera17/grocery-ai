import SwiftUI

struct ProductQuantityControl: View {
    @Binding var item: SelectableProduct

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Button("Reducir cantidad", systemImage: "minus", action: decrease)
                .labelStyle(.iconOnly)
                .frame(width: AppControlSize.minimumTapTarget, height: AppControlSize.minimumTapTarget)
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(item.product.quantity <= item.quantityStep)

            Text(item.product.quantityDescription)
                .font(.subheadline.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            Button("Aumentar cantidad", systemImage: "plus", action: increase)
                .labelStyle(.iconOnly)
                .frame(width: AppControlSize.minimumTapTarget, height: AppControlSize.minimumTapTarget)
                .glassEffect(.regular.interactive(), in: .circle)
                .disabled(item.product.quantity >= item.maximumQuantity)
        }
        .accessibilityElement(children: .contain)
    }

    private func decrease() {
        item.product.quantity = max(
            item.quantityStep,
            item.product.quantity - item.quantityStep
        )
    }

    private func increase() {
        item.product.quantity = min(
            item.maximumQuantity,
            item.product.quantity + item.quantityStep
        )
    }
}
