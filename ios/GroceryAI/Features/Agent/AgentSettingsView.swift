import SwiftUI

struct AgentSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accessPassword = ""
    @State private var hasSavedPassword = APIAccess.password() != nil
    @State private var accessError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Backend") {
                    LabeledContent("Servidor", value: APIConfiguration.baseURL.absoluteString)
                    SecureField("Contraseña de acceso", text: $accessPassword)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                    Button("Guardar acceso") {
                        do {
                            try APIAccess.savePassword(accessPassword)
                            accessPassword = ""
                            hasSavedPassword = true
                            accessError = nil
                        } catch {
                            accessError = error.localizedDescription
                        }
                    }
                    .disabled(accessPassword.isEmpty)
                    if hasSavedPassword {
                        Label("Acceso guardado en este iPhone", systemImage: "checkmark.shield")
                        Button("Eliminar acceso", role: .destructive) {
                            try? APIAccess.savePassword("")
                            hasSavedPassword = false
                        }
                    }
                    if let accessError {
                        Text(accessError).foregroundStyle(.red)
                    }
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
