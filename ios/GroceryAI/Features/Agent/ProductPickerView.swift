import SwiftUI

struct ProductPickerView: View {
    let products: [ProductRequest]
    let onAdd: (ProductRequest) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if products.isEmpty {
                    EmptyStateView(
                        title: "Sin productos frecuentes",
                        systemImage: "repeat",
                        message: "Completa una comparación para crear tu historial."
                    )
                } else {
                    List(products) { product in
                        Button {
                            onAdd(product)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(product.name)
                                    Text(product.quantityDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Productos frecuentes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
