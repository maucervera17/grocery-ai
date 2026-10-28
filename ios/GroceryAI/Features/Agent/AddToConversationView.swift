import SwiftUI

struct AddToConversationView: View {
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var items: [SelectableProduct]
    @State private var searchText = ""
    private let initialSection: AddContentSection

    init(initialSection: AddContentSection = .products, appState: AppState) {
        self.appState = appState
        self.initialSection = initialSection
        _items = State(initialValue: appState.frequentProductOptions.map {
            SelectableProduct(product: $0.product, imageURL: $0.imageURL, isSelected: false)
        })
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                        ProductPickerView(items: $items, searchText: searchText)

                        PreviousOrderPickerView(
                            orders: appState.orders,
                            searchText: searchText
                        )
                    }
                    .padding(AppSpacing.large)
                }
                .task {
                    guard initialSection == .orders else { return }
                    await Task.yield()
                    proxy.scrollTo(AddContentSection.orders, anchor: .top)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedProducts.isEmpty {
                    AddProductsButton(title: addButtonTitle, action: addSelectedProducts)
                        .padding(.horizontal, AppSpacing.large)
                        .padding(.vertical, AppSpacing.medium)
                }
            }
            .navigationTitle("Agregar productos")
            .toolbarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Buscar en tu historial")
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .navigationDestination(for: CompletedOrder.self) { order in
                PreviousOrderSelectionView(order: order, onAdd: addProducts)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark", action: dismiss.callAsFunction)
                        .labelStyle(.iconOnly)
                }
            }
        }
    }

    private func addProducts(_ products: [ProductRequest]) {
        appState.addProducts(products)
        dismiss()
    }

    private var selectedProducts: [ProductRequest] {
        items.filter(\.isSelected).map(\.product)
    }

    private var addButtonTitle: LocalizedStringKey {
        selectedProducts.count == 1
            ? "Agregar 1 producto"
            : "Agregar \(selectedProducts.count) productos"
    }

    private func addSelectedProducts() {
        addProducts(selectedProducts)
    }
}
