import SwiftUI

struct AgentEmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Crea tu lista del súper", systemImage: "basket")
        } description: {
            Text("Escribe productos con cantidad o reutiliza una compra.")
        }
    }
}
