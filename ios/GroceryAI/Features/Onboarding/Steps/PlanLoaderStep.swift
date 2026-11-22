import SwiftUI

/// Real loader: each store line is checked when its basket quote arrives.
struct PlanLoaderStep: View {
    let model: OnboardingModel

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .callout) private var statusIconWidth: CGFloat = 22

    private enum LineState { case done, loading, failed }

    private var lines: [(text: String, state: LineState)] {
        let answers = model.answers
        var household = answers.householdSize?.householdPhrase ?? "Tu hogar"
        if let cadence = answers.shoppingFrequency?.cadencePhrase {
            household += ", súper \(cadence)"
        }
        var result: [(String, LineState)] = [
            (household, .done),
            ("Armando tu canasta básica con marcas", .done)
        ]
        for store in model.quotedStores {
            switch model.quoteStatuses[store] {
            case .done: result.append(("Precios en línea de \(store.title)", .done))
            case .failed: result.append(("No pudimos consultar \(store.title)", .failed))
            default: result.append(("Consultando \(store.title)", .loading))
            }
        }
        return result
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        ScrollView {
            VStack(spacing: AppSpacing.extraLarge) {
                AgentAvatarView()

                VStack(spacing: AppSpacing.small) {
                    Text("Preparando tu plan")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Consultamos la misma canasta en cada tienda.")
                        .font(AppTypography.body)
                        .foregroundStyle(colors.textSecondary)
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: AppSpacing.medium) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: AppSpacing.medium) {
                            Group {
                                switch line.state {
                                case .done:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(colors.statusSuccess)
                                case .loading:
                                    ProgressView()
                                        .controlSize(.small)
                                case .failed:
                                    Image(systemName: "exclamationmark.circle")
                                        .foregroundStyle(colors.textSecondary)
                                }
                            }
                            .frame(width: statusIconWidth)
                            Text(line.text)
                                .font(.callout)
                                .foregroundStyle(line.state == .loading ? colors.textSecondary : colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: AppControlSize.minimumTapTarget)
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: 360)
                .animation(reduceMotion ? nil : .smooth, value: model.quoteStatuses)
            }
            .padding(AppSpacing.extraLarge)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(colors.backgroundPrimary)
        .task { model.runBasketQuote() }
        .onAppear { OnboardingEvent.stepViewed(.planLoader).log() }
    }
}
