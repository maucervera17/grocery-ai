import SwiftUI

struct ProductEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var product: ProductRequest
    let onSave: (ProductRequest) -> Void

    init(product: ProductRequest, onSave: @escaping (ProductRequest) -> Void) {
        _product = State(initialValue: product)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Producto") {
                    TextField("Nombre", text: $product.name)
                    TextField("Notas opcionales", text: Binding(
                        get: { product.notes ?? "" },
                        set: { product.notes = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Cantidad") {
                    TextField("Cantidad", value: $product.quantity, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Unidad", selection: $product.unit) {
                        ForEach(ProductUnit.allCases, id: \.self) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            }
            .navigationTitle("Editar producto")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(product)
                        dismiss()
                    }
                    .disabled(product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || product.quantity <= 0)
                }
            }
        }
    }
}
