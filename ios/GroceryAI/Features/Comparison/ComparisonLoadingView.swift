import SwiftUI

struct ComparisonLoadingView: View {
    var message: String = "Comparando supermercados"

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(spacing: AppSpacing.extraLarge) {
            ProgressView()
                .controlSize(.large)
                .tint(colors.brandPrimary)
                .accessibilityLabel("Comparación en progreso")

            VStack(spacing: AppSpacing.small) {
                Text(message)
                    .font(.title2.bold())

                Text("Estamos buscando la combinación con el menor costo estimado.")
                    .font(.body)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Text("Los totales no incluyen transporte ni entrega.")
                .font(.footnote)
                .foregroundStyle(colors.textSecondary)
        }
        .padding(AppSpacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.backgroundPrimary)
        .animation(reduceMotion ? nil : .default, value: message)
    }
}

#Preview {
    ComparisonLoadingView()
}
