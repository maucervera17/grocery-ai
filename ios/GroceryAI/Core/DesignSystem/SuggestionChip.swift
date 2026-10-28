import SwiftUI

struct SuggestionChip: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isSelected = isSelected
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
            .font(AppTypography.supporting)
            .bold()
            .frame(minHeight: 44)
            .padding(.horizontal, AppSpacing.large)
            .foregroundStyle(isSelected ? colors.brandOnPrimary : colors.textPrimary)
            .background(backgroundColor, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(isSelected ? colors.brandPrimary : colors.borderSubtle, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundColor: Color {
        isSelected ? colors.brandPrimary : colors.surfacePrimary
    }

    private var colors: AppThemeColors {
        theme.colors(for: colorScheme)
    }
}
