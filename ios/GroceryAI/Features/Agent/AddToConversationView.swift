import SwiftUI

struct AddToConversationView: View {
    let appState: AppState

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: AddContentDestination.frequentProducts) {
                    AddToConversationRow(
                        title: "Productos frecuentes",
                        subtitle: "Elige tus habituales",
                        systemImage: "star.fill",
                        tint: .green
                    )
                }

                NavigationLink(value: AddContentDestination.previousOrders) {
                    AddToConversationRow(
                        title: "Compras anteriores",
                        subtitle: "Reutiliza una lista",
                        systemImage: "clock.arrow.circlepath",
                        tint: .blue
                    )
                }

                NavigationLink(value: AddContentDestination.manualList) {
                    AddToConversationRow(
                        title: "Escribir una lista",
                        subtitle: "Pega varios productos",
                        systemImage: "list.bullet",
                        tint: .purple
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Agregar productos")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: AddContentDestination.self) { destination in
                switch destination {
                case .frequentProducts:
                    ProductPickerView(products: appState.frequentProducts, onAdd: appState.addProduct)
                case .previousOrders:
                    PreviousOrderPickerView(orders: appState.orders, onSelect: appState.repeatOrder)
                case .manualList:
                    ManualListView { list in
                        Task { await appState.send(list) }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark", action: dismiss.callAsFunction)
                }
            }
        }
    }
}
