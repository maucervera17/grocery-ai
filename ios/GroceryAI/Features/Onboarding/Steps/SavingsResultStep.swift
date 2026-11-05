import SwiftUI

struct SavingsResultStep: View {
    let answers: OnboardingAnswers
    let estimate: SavingsEstimator.Estimate
    let onContinue: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var revealProgress = 0.0

    var body: some View {
        let colors = theme.colors(for: colorScheme)
        let isAccessibilitySize = dynamicTypeSize.isAccessibilitySize
        let headerLayout = isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: AppSpacing.small))
            : AnyLayout(HStackLayout(spacing: AppSpacing.small))
        let statsLayout = isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: AppSpacing.medium))
            : AnyLayout(HStackLayout(spacing: 0))

        OnboardingScaffold(
            step: .savingsResult,
            layout: .centered,
            footer: {
            GlassProminentButton("¿Cómo lo hago?", action: onContinue)
            },
            content: {
            VStack(spacing: AppSpacing.section) {
                VStack(spacing: AppSpacing.small) {
                    headerLayout {
                        Text("Podrías ahorrar")
                            .font(AppTypography.body)
                            .foregroundStyle(colors.textSecondary)
                        StatusBadge("Estimado", systemImage: "info.circle", kind: .information)
                            .fixedSize()
                    }

                    if isAccessibilitySize {
                        VStack(spacing: 0) {
                            rangeFigure("\(DisplayPriceFormatter.string(cents: displayedLowCents)) a", colors: colors)
                            rangeFigure(DisplayPriceFormatter.string(cents: displayedHighCents), colors: colors)
                        }
                        .accessibilityElement(children: .combine)
                    } else {
                        rangeFigure(rangeText, colors: colors)
                    }

                    Text("al mes")
                        .font(AppTypography.body)
                        .foregroundStyle(colors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                statsLayout {
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

    private func rangeFigure(_ text: String, colors: AppThemeColors) -> some View {
        // Same size as every onboarding title (OnboardingScaffold).
        Text(text)
            .font(.title.weight(.semibold))
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundStyle(colors.textPrimary)
            .contentTransition(.numericText())
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private func hairline(colors: AppThemeColors) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Rectangle()
                .fill(colors.borderSubtle)
                .frame(maxWidth: .infinity)
                .frame(height: 0.5)
        } else {
            Rectangle()
                .fill(colors.borderSubtle)
                .frame(width: 0.5, height: 36)
        }
    }

    private func statColumn(value: String, label: String, colors: AppThemeColors) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(colors.textPrimary)
            Text(label)
                .font(.footnote)
                .foregroundStyle(colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
        "hasta \(DisplayPriceFormatter.string(cents: estimate.annualHighCents))"
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
