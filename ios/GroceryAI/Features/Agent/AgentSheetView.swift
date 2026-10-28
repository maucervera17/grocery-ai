import SwiftUI

struct AgentSheetView: View {
    let destination: AgentSheet
    let appState: AppState

    var body: some View {
        switch destination {
        case .addContent(let section):
            AddToConversationView(initialSection: section, appState: appState)
                .presentationDetents([.fraction(0.88)])
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
