import SwiftUI

struct AddToConversationView: View {
    let appState: AppState

    @Environment(\.dismiss) private var dismiss
    @State private var section: AddContentSection

    init(initialSection: AddContentSection = .products, appState: AppState) {
        self.appState = appState
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Contenido", selection: $section) {
                    ForEach(AddContentSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.medium)

                switch section {
                case .products:
                    ProductPickerView(products: appState.frequentProducts, onAdd: addProducts)
                case .orders:
                    PreviousOrderPickerView(orders: appState.orders, onAdd: addProducts)
                }
            }
            .navigationTitle("Agregar productos")
            .toolbarTitleDisplayMode(.inline)
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
}
