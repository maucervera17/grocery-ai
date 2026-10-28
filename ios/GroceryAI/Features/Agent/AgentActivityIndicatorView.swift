import SwiftUI

struct AgentActivityIndicatorView: View {
    let loadingState: ChatLoadingState

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(alignment: .bottom, spacing: AppSpacing.small) {
            AgentAvatarView()

            HStack(spacing: AppSpacing.small) {
                ProgressView()
                    .controlSize(.small)

                Text(statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.medium)
            .background(colors.surfacePrimary, in: .rect(cornerRadius: AppRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(colors.borderSubtle)
            }

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Barasu: \(statusText)")
    }

    private var statusText: String {
        switch loadingState {
        case .updatingDraft:
            "Actualizando tu lista"
        case .comparing:
            "Comparando supermercados"
        case .idle, .failed:
            "Procesando"
        }
    }
}
