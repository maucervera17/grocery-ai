import SwiftUI

struct LoadingStateView: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey?

    init(
        _ title: LocalizedStringKey = "Cargando",
        message: LocalizedStringKey? = nil
    ) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            ProgressView()
                .controlSize(.large)
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypography.cardTitle)

            if let message {
                Text(message)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.extraLarge)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
