import SwiftUI

struct PreviousOrderSelectionView: View {
    let order: CompletedOrder
    let onAdd: ([ProductRequest]) -> Void

    @State private var items: [SelectableProduct]

    init(order: CompletedOrder, onAdd: @escaping ([ProductRequest]) -> Void) {
        self.order = order
        self.onAdd = onAdd
        _items = State(initialValue: order.requestedItems.map {
            SelectableProduct(product: $0, isSelected: true)
        })
    }

    var body: some View {
        List($items) { $item in
            SelectableProductRow(item: $item)
        }
        .safeAreaInset(edge: .bottom) {
            AddProductsButton(title: addButtonTitle) {
                onAdd(selectedProducts)
            }
            .disabled(selectedProducts.isEmpty)
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
        }
        .navigationTitle("Elegir productos")
        .toolbarTitleDisplayMode(.inline)
    }

    private var selectedProducts: [ProductRequest] {
        items.filter(\.isSelected).map(\.product)
    }

    private var addButtonTitle: LocalizedStringKey {
        if selectedProducts.count == order.requestedItems.count {
            return "Agregar toda la compra"
        }
        let count = selectedProducts.count
        return count == 1 ? "Agregar 1 producto" : "Agregar \(count) productos"
    }
}
