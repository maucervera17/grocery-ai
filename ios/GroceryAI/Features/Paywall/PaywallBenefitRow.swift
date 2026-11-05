import SwiftUI

struct PaywallBenefitRow: View {
    let benefit: PaywallBenefit

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(spacing: AppSpacing.medium) {
            Image(systemName: benefit.systemImage)
                .font(.body)
                .foregroundStyle(colors.brandPrimary)
                .frame(width: 36, height: 36)
                .background(colors.backgroundSecondary, in: .circle)
                .accessibilityHidden(true)

            Text(benefit.title)
                .font(AppTypography.body)
                .foregroundStyle(colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
