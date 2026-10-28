import SwiftUI

struct AgentStatusView: View {
    let loadingState: ChatLoadingState

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Label(statusTitle, systemImage: statusSymbol)
            .font(.subheadline)
            .foregroundStyle(statusColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Estado del agente: \(statusTitle)")
    }

    private var statusTitle: String {
        switch loadingState {
        case .idle:
            "Agente listo"
        case .updatingDraft:
            "Actualizando tu lista"
        case .comparing:
            "Comparando supermercados"
        case .failed:
            "Requiere atención"
        }
    }

    private var statusSymbol: String {
        switch loadingState {
        case .idle:
            "circle.fill"
        case .updatingDraft, .comparing:
            "ellipsis.circle.fill"
        case .failed:
            "exclamationmark.circle.fill"
        }
    }

    private var statusColor: Color {
        let colors = theme.colors(for: colorScheme)
        switch loadingState {
        case .idle:
            return colors.statusSuccess
        case .updatingDraft, .comparing:
            return colors.statusInformation
        case .failed:
            return colors.statusError
        }
    }
}
