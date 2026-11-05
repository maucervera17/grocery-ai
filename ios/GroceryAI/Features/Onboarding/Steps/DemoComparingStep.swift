import SwiftUI

struct DemoComparingStep: View {
    let model: OnboardingModel

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(spacing: AppSpacing.extraLarge) {
            ProgressView()
                .controlSize(.large)
                .tint(colors.brandPrimary)
                .accessibilityLabel("Comparación en progreso")

            VStack(spacing: AppSpacing.small) {
                Text("Comparando precios")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(colors.textPrimary)
                Text("Buscando el menor total en Walmart, Bodega Aurrera y Chedraui.")
                    .font(.body)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                if model.showsDemoSlowMessage {
                    Text("Sigue buscando precios…")
                        .font(.callout)
                        .foregroundStyle(colors.textSecondary)
                        .transition(.opacity)
                }
            }
        }
        .padding(AppSpacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.backgroundPrimary)
        .animation(.smooth, value: model.showsDemoSlowMessage)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            OnboardingEvent.stepViewed(.demoComparing).log()
            model.runDemoComparison()
        }
    }
}
