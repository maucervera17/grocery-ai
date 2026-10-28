import SwiftUI

struct StatusBadge: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let kind: StatusBadgeKind

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        kind: StatusBadgeKind = .neutral
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(AppTypography.supporting)
            .bold()
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, AppSpacing.medium)
            .padding(.vertical, AppSpacing.small)
            .background(foregroundColor.opacity(0.14), in: .capsule)
    }

    private var foregroundColor: Color {
        switch kind {
        case .neutral:
            colors.textSecondary
        case .success:
            colors.statusSuccess
        case .warning:
            colors.statusWarning
        case .error:
            colors.statusError
        case .information:
            colors.statusInformation
        case .demo:
            colors.statusInformation
        }
    }

    private var colors: AppThemeColors {
        theme.colors(for: colorScheme)
    }
}
