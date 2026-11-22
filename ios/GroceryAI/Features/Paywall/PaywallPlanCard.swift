import SwiftUI

struct PaywallPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let savingsPercent: Int?
    let monthlyEquivalentCents: Int?
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    stackedLayout(colors: colors)
                } else {
                    rowLayout(colors: colors)
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
                if !dynamicTypeSize.isAccessibilitySize {
                    savingsBadge(colors: colors)
                        .offset(y: -AppSpacing.medium)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func rowLayout(colors: AppThemeColors) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.medium) {
            selectionIcon(colors: colors)
            details(colors: colors)
            Spacer(minLength: AppSpacing.small)
            VStack(alignment: .trailing, spacing: 0) {
                billedPrice(colors: colors)
                    .fixedSize()
                periodLabel(colors: colors)
            }
        }
    }

    /// Accessibility sizes: stack name, billed price and details so nothing truncates.
    /// The billed price stays the largest text on the card.
    private func stackedLayout(colors: AppThemeColors) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.small) {
                selectionIcon(colors: colors)
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
            }
            savingsBadge(colors: colors)
            billedPrice(colors: colors)
                .fixedSize(horizontal: false, vertical: true)
            periodLabel(colors: colors)
            details(colors: colors, showsTitle: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionIcon(colors: AppThemeColors) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? colors.brandPrimary : colors.textSecondary)
            .accessibilityHidden(true)
    }

    private func details(colors: AppThemeColors, showsTitle: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if showsTitle {
                Text(plan.title)
                    .font(.headline)
                    .foregroundStyle(colors.textPrimary)
            }
            Text(secondaryLine)
                .font(AppTypography.supporting)
                .foregroundStyle(colors.textSecondary)
            if let monthlyEquivalentCents {
                Text("Equivale a \(DisplayPriceFormatter.string(cents: monthlyEquivalentCents)) al mes")
                    .font(AppTypography.supporting)
                    .foregroundStyle(colors.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func billedPrice(colors: AppThemeColors) -> some View {
        Text(DisplayPriceFormatter.string(cents: plan.priceCents))
            .font(.title2.weight(.semibold))
            .fontDesign(.rounded)
            .monospacedDigit()
            .foregroundStyle(colors.textPrimary)
    }

    private func periodLabel(colors: AppThemeColors) -> some View {
        Text("/\(plan.periodName)")
            .font(.footnote)
            .foregroundStyle(colors.textSecondary)
    }

    @ViewBuilder
    private func savingsBadge(colors: AppThemeColors) -> some View {
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
        }
    }

    private var secondaryLine: String {
        plan.trialDays != nil
            ? "\(plan.trialDays ?? 0) días gratis"
            : "Sin prueba gratis"
    }
}
