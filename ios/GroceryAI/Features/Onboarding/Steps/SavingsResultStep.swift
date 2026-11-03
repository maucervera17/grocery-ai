import SwiftUI

struct SavingsResultStep: View {
    let answers: OnboardingAnswers
    let estimate: SavingsEstimator.Estimate
    let onContinue: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealProgress = 0.0
    @ScaledMetric private var figureSize: CGFloat = 56

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        OnboardingScaffold(
            step: .savingsResult,
            layout: .centered,
            footer: {
            GlassProminentButton("¿Cómo lo hago?", action: onContinue)
            },
            content: {
            VStack(spacing: AppSpacing.section) {
                VStack(spacing: AppSpacing.small) {
                    HStack(spacing: AppSpacing.small) {
                        Text("Podrías ahorrar")
                            .font(.title3)
                            .foregroundStyle(colors.textSecondary)
                        StatusBadge("Estimado", systemImage: "info.circle", kind: .information)
                    }

                    Text(rangeText)
                        .font(.system(size: figureSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(colors.textPrimary)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text("al mes")
                        .font(.title3)
                        .foregroundStyle(colors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 0) {
                    statColumn(value: annualText, label: "al año", colors: colors)
                    hairline(colors: colors)
                    statColumn(
                        value: "\(answers.shoppingFrequency?.tripsPerMonth ?? 4)",
                        label: "compras al mes",
                        colors: colors
                    )
                    hairline(colors: colors)
                    statColumn(value: "3", label: "súpers cerca", colors: colors)
                }

                Text("Estimación con diferencias de precio publicadas por Profeco. Tu ahorro real depende de tu lista y tu zona.")
                    .font(.caption)
                    .foregroundStyle(colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            }
        )
        .sensoryFeedback(.success, trigger: revealProgress >= 1)
        .task { countUp() }
    }

    private func hairline(colors: AppThemeColors) -> some View {
        Rectangle()
            .fill(colors.borderSubtle)
            .frame(width: 0.5, height: 36)
    }

    private func statColumn(value: String, label: String, colors: AppThemeColors) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(colors.textPrimary)
            Text(label)
                .font(.footnote)
                .foregroundStyle(colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayedLowCents: Int {
        Int(Double(estimate.lowCents) * revealProgress)
    }

    private var displayedHighCents: Int {
        Int(Double(estimate.highCents) * revealProgress)
    }

    private var rangeText: String {
        "\(DisplayPriceFormatter.string(cents: displayedLowCents)) – \(DisplayPriceFormatter.string(cents: displayedHighCents))"
    }

    private var annualText: String {
        DisplayPriceFormatter.string(cents: estimate.annualHighCents)
    }

    private func countUp() {
        if reduceMotion {
            revealProgress = 1
            return
        }
        Task { @MainActor in
            for step in 1...20 {
                try? await Task.sleep(for: .milliseconds(45))
                revealProgress = Double(step) / 20
            }
        }
    }
}
