import SwiftUI

struct PlanLoaderStep: View {
    let answers: OnboardingAnswers
    let onFinished: () -> Void
    var warmUp: () -> Void = {}

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var completedLines = 0

    private var lines: [String] {
        var result: [String] = []
        let household = answers.householdSize?.householdPhrase ?? "Tu hogar"
        let cadence = answers.shoppingFrequency?.cadencePhrase
        result.append(cadence.map { "\(household), súper \($0)" } ?? household)
        if answers.postalCode.isEmpty {
            result.append("Revisando tiendas disponibles")
        } else {
            result.append("Revisando tiendas cerca de \(answers.postalCode)")
        }
        result.append("Comparando Walmart, Bodega Aurrera y Chedraui")
        result.append("Calculando tu ahorro")
        return result
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(spacing: AppSpacing.extraLarge) {
            AgentAvatarView()

            Text("Preparando tu plan")
                .font(.title.weight(.semibold))
                .foregroundStyle(colors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: AppSpacing.medium) {
                        if index < completedLines {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(colors.statusSuccess)
                        } else if index == completedLines {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(colors.borderSubtle)
                        }
                        Text(line)
                            .font(.callout)
                            .foregroundStyle(
                                index <= completedLines ? colors.textPrimary : colors.textSecondary
                            )
                        Spacer()
                    }
                    .frame(minHeight: AppControlSize.minimumTapTarget)
                }
            }
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colors.backgroundPrimary)
        .task { runSequence() }
        .onAppear {
            OnboardingEvent.stepViewed(.planLoader).log()
            warmUp()
        }
    }

    private func runSequence() {
        Task { @MainActor in
            let interval = reduceMotion ? 0.35 : 0.8
            for index in lines.indices {
                try? await Task.sleep(for: .seconds(interval))
                withAnimation(reduceMotion ? nil : .smooth) {
                    completedLines = index + 1
                }
            }
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}
