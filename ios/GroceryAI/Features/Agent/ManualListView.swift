import SwiftUI

struct ManualListView: View {
    let onSubmit: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var list = ""

    var body: some View {
        Form {
            Section {
                TextField(
                    "Ejemplo:\n2 litros de leche\n12 huevos\n1 kg de arroz",
                    text: $list,
                    axis: .vertical
                )
                .lineLimit(6...12)
            } header: {
                Text("Productos")
            }
        }
        .navigationTitle("Escribir una lista")
        .toolbarTitleDisplayMode(.inlineLarge)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton("Agregar lista", systemImage: "plus") {
                onSubmit(list)
                dismiss()
            }
            .disabled(list.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(AppSpacing.large)
            .background(.bar)
        }
    }
}
