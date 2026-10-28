import SwiftUI

struct DraftCard: View {
    let draft: ShoppingDraft
    let onEdit: (ProductRequest) -> Void
    let onDelete: (IndexSet) -> Void

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack {
                    Label("Tu borrador", systemImage: "list.bullet.clipboard")
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
            }
        }
    }
}
