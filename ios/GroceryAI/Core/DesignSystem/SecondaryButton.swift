import SwiftUI

struct SecondaryButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let expandsHorizontally: Bool
    private let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        expandsHorizontally: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.expandsHorizontally = expandsHorizontally
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }

                Text(title)
            }
            .font(AppTypography.action)
            .frame(maxWidth: expandsHorizontally ? .infinity : nil, minHeight: 44)
            .padding(.horizontal, AppSpacing.large)
            .foregroundStyle(colors.brandPrimary)
            .background(colors.surfacePrimary, in: .rect(cornerRadius: AppRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(colors.borderSubtle, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
    }

    private var colors: AppThemeColors {
        theme.colors(for: colorScheme)
    }
}
