import SwiftUI

struct ProductPickerView: View {
    let onAdd: ([ProductRequest]) -> Void

    @State private var items: [SelectableProduct]

    init(products: [ProductRequest], onAdd: @escaping ([ProductRequest]) -> Void) {
        self.onAdd = onAdd
        _items = State(initialValue: products.map { SelectableProduct(product: $0, isSelected: false) })
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Sin productos frecuentes",
                    systemImage: "basket",
                    description: Text("Los productos aparecerán después de guardar comparaciones.")
                )
            } else {
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
            }
        }
    }

    private var selectedProducts: [ProductRequest] {
        items.filter(\.isSelected).map(\.product)
    }

    private var addButtonTitle: LocalizedStringKey {
        let count = selectedProducts.count
        return count == 1 ? "Agregar 1 producto" : "Agregar \(count) productos"
    }
}
