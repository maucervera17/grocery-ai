import SwiftUI

struct AgentSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    LabeledContent("Servidor", value: APIConfiguration.baseURL.absoluteString)
                    LabeledContent("Datos", value: "Demostración")
                }
            }
            .navigationTitle("Configuración")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", action: dismiss.callAsFunction)
                }
            }
        }
    }
}
