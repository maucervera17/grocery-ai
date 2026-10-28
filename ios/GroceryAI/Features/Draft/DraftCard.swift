import SwiftUI

struct DraftCard: View {
    let draft: ShoppingDraft
    let onEdit: (ProductRequest) -> Void
    let onDelete: (IndexSet) -> Void
    let onCompare: () -> Void

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Lista actual", systemImage: "sparkles")
                        .font(.headline)
                    Spacer()
                    Text("\(draft.items.count) productos")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(draft.items.enumerated()), id: \.element.id) { index, product in
                    DraftProductRow(product: product) {
                        onEdit(product)
                    } onDelete: {
                        onDelete(IndexSet(integer: index))
                    }

                    if index < draft.items.count - 1 { Divider() }
                }

                PrimaryButton("Comparar precios", systemImage: "cart.badge.questionmark", action: onCompare)
            }
        }
    }
}
