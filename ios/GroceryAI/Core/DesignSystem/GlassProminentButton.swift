import SwiftUI

struct GlassProminentButton: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let isLoading: Bool
    private let expandsHorizontally: Bool
    private let action: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        isLoading: Bool = false,
        expandsHorizontally: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.expandsHorizontally = expandsHorizontally
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.small) {
                if isLoading {
                    ProgressView()
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
            .font(AppTypography.action)
            .frame(maxWidth: expandsHorizontally ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(colors.brandPrimary)
        .controlSize(.large)
        .disabled(isLoading)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityValue(isLoading ? Text("Procesando") : Text(""))
    }

    private var colors: AppThemeColors {
        theme.colors(for: colorScheme)
    }
}
