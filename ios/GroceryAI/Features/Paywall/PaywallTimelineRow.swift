import SwiftUI

struct PaywallTimelineRow: View {
    let title: String
    let detail: String
    let isLast: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var markerWidth: CGFloat = 20

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.medium) {
            Image(systemName: "circle.fill")
                .font(.footnote)
                .foregroundStyle(colors.brandPrimary)
                .frame(width: markerWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.extraSmall) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(colors.textPrimary)

                Text(detail)
                    .font(AppTypography.supporting)
                    .foregroundStyle(colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : AppSpacing.section)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(colors.brandPrimary.opacity(0.35))
                    .frame(width: 2)
                    .padding(.leading, (markerWidth - 2) / 2)
                    .padding(.top, AppSpacing.large)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
