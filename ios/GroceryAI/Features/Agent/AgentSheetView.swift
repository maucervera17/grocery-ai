import SwiftUI

struct AgentSheetView: View {
    let destination: AgentSheet
    let appState: AppState

    var body: some View {
        switch destination {
        case .addContent:
            AddToConversationView(appState: appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        case .editProduct(let product):
            ProductEditorView(product: product, onSave: appState.updateProduct)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        case .location:
            LocationFlowSheet(appState: appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        case .settings:
            AgentSettingsView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}
