import SwiftUI

struct DraftCard: View {
    private static let collapsedItemLimit = 5

    let draft: ShoppingDraft
    let imageURLs: [UUID: URL]
    let onEdit: (ProductRequest) -> Void
    let onDelete: (IndexSet) -> Void
    let onCompare: () -> Void

    @State private var isExpanded = false

    var body: some View {
        let indexedItems = Array(draft.items.enumerated())
        let visibleItems = isExpanded
            ? indexedItems
            : Array(indexedItems.prefix(Self.collapsedItemLimit))

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

                ForEach(visibleItems, id: \.element.id) { index, product in
                    DraftProductRow(product: product, imageURL: imageURLs[product.id]) {
                        onEdit(product)
                    } onDelete: {
                        onDelete(IndexSet(integer: index))
                    }
                }

                if draft.items.count > Self.collapsedItemLimit {
                    Button(
                        isExpanded ? "Ver menos" : "Ver \(draft.items.count - Self.collapsedItemLimit) más",
                        systemImage: isExpanded ? "minus.circle" : "plus.circle",
                        action: toggleExpanded
                    )
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }

                PrimaryButton("Comparar precios", systemImage: "cart.badge.questionmark", action: onCompare)
            }
        }
        .onChange(of: draft.items.count) {
            if draft.items.count <= Self.collapsedItemLimit {
                isExpanded = false
            }
        }
    }

    private func toggleExpanded() {
        isExpanded.toggle()
    }
}
