import SwiftUI

struct SurfaceCard<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(
        padding: CGFloat = AppSpacing.large,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(colors.surfacePrimary, in: .rect(cornerRadius: AppRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .stroke(colors.borderSubtle, lineWidth: 1)
            }
    }

    private var colors: AppThemeColors {
        theme.colors(for: colorScheme)
    }
}
