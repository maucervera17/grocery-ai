import SwiftUI

struct OnboardingOptionRow: View {
    let title: String
    var systemImage: String?
    var retailerID: RetailerID?
    var logoAssetName: String?
    var badge: String?
    var detail: String?
    var isEnabled = true
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        Button(action: action) {
            HStack(spacing: AppSpacing.medium) {
                leadingVisual

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(colors.textPrimary)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(colors.textSecondary)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: AppSpacing.small)

                Image(systemName: isEnabled ? (isSelected ? "checkmark.circle.fill" : "circle") : "clock")
                    .font(.title3)
                    .foregroundStyle(isSelected ? colors.brandPrimary : colors.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, AppSpacing.large)
            .padding(.vertical, AppSpacing.large)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(
                isSelected ? colors.brandSecondary : colors.cellBackground,
                in: .rect(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(colors.brandPrimary, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
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
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var leadingVisual: some View {
        let colors = theme.colors(for: colorScheme)
        if let logoAssetName {
            Image(logoAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 22)
                .frame(width: 40, height: 40)
                .background(.white, in: .rect(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
        } else if let retailerID {
            RetailerLogo(retailerID: retailerID, retailerName: title)
                .frame(width: 40, height: 40)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(isSelected ? colors.brandPrimary : colors.textSecondary)
                .frame(width: 40, height: 40)
                .background(colors.backgroundSecondary, in: .circle)
                .accessibilityHidden(true)
        }
    }
}
