import SwiftUI

struct PaywallPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let savingsPercent: Int?
    let monthlyEquivalentCents: Int?
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? colors.brandPrimary : colors.textSecondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(colors.textPrimary)
                    Text(secondaryLine)
                        .font(AppTypography.supporting)
                        .foregroundStyle(colors.textSecondary)
                    if let monthlyEquivalentCents {
                        Text("Equivale a \(DisplayPriceFormatter.string(cents: monthlyEquivalentCents)) al mes")
                            .font(AppTypography.supporting)
                            .foregroundStyle(colors.textSecondary)
                    }
                }

                Spacer(minLength: AppSpacing.small)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(DisplayPriceFormatter.string(cents: plan.priceCents))
                        .font(.title2.weight(.semibold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(colors.textPrimary)
                        .fixedSize()
                    Text("/\(plan.periodName)")
                        .font(.footnote)
                        .foregroundStyle(colors.textSecondary)
                }
            }
            .padding(AppSpacing.large)
            .background(
                isSelected ? colors.brandSecondary : colors.surfacePrimary,
                in: .rect(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        isSelected ? colors.brandPrimary : colors.borderSubtle,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(.rect(cornerRadius: 22))
            .overlay(alignment: .topTrailing) {
                if let savingsPercent, savingsPercent > 0 {
                    Label("Ahorra \(savingsPercent)%", systemImage: "tag")
                        .font(.caption2.bold())
                        .foregroundStyle(colors.brandOnPrimary)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, AppSpacing.extraSmall)
                        .background(colors.brandPrimary, in: .capsule)
                        .overlay {
                            Capsule()
                                .stroke(colors.backgroundPrimary, lineWidth: 2)
                        }
                        .offset(y: -AppSpacing.medium)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var secondaryLine: String {
        plan.trialDays != nil
            ? "\(plan.trialDays ?? 0) días gratis"
            : "Sin prueba gratis"
    }
}
