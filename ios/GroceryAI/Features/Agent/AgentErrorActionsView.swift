import SwiftUI

struct AgentErrorActionsView: View {
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.small) {
            Label("No se actualizó la lista", systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Reintentar", action: onRetry)
                .buttonStyle(.bordered)

            Button("Descartar", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, AppSpacing.large)
        .padding(.vertical, AppSpacing.small)
    }
}
