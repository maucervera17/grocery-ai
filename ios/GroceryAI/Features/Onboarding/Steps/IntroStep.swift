import SwiftUI

struct IntroStep: View {
    let step = OnboardingStep.intro
    let onContinue: () -> Void
    var onBack: (() -> Void)?

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleSteps = 0

    private let pathSteps: [(String, String)] = [
        ("Tus hábitos", "Cómo compras hoy"),
        ("Tu ahorro estimado", "Con precios publicados por Profeco"),
        ("Una prueba con tu lista", "Con 2 productos de verdad")
    ]

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: step,
            onBack: onBack,
            layout: .centered,
            footer: {
            GlassProminentButton("Continuar", action: onContinue)
            },
            content: {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                VStack(alignment: .leading, spacing: AppSpacing.small) {
                    Text("Armemos tu plan de ahorro")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                    Text("\(OnboardingStep.questionSteps.count) preguntas rápidas, unos 2 minutos")
                        .font(AppTypography.body)
                        .foregroundStyle(colors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(pathSteps.enumerated()), id: \.offset) { index, item in
                        if index < visibleSteps {
                            HStack(alignment: .top, spacing: AppSpacing.medium) {
                                ZStack {
                                    Circle()
                                        .fill(index == 0 ? colors.brandPrimary : colors.backgroundSecondary)
                                        .frame(width: 32, height: 32)
                                    Text("\(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                        .fontDesign(.rounded)
                                        .monospacedDigit()
                                        .foregroundStyle(index == 0 ? colors.brandOnPrimary : colors.textSecondary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.0)
                                        .font(.headline)
                                        .foregroundStyle(colors.textPrimary)
                                    Text(item.1)
                                        .font(.callout)
                                        .foregroundStyle(colors.textSecondary)
                                }
                            }
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
                        }

                        if index < pathSteps.count - 1 {
                            Rectangle()
                                .fill(colors.borderSubtle)
                                .frame(width: 2, height: 28)
                                .padding(.leading, 15)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
        )
        .task { appear() }
    }

    private func appear() {
        if reduceMotion {
            visibleSteps = pathSteps.count
            return
        }
        Task { @MainActor in
            for index in 1...pathSteps.count {
                withAnimation(.easeOut(duration: 0.35)) { visibleSteps = index }
                try? await Task.sleep(for: .milliseconds(160))
            }
        }
    }
}
