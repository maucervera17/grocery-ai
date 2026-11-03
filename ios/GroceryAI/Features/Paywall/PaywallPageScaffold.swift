import SwiftUI

struct PaywallPageScaffold<Content: View, Footer: View>: View {
    private let onBack: (() -> Void)?
    private let content: Content
    private let footer: Footer

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.onBack = onBack
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.large)
                .padding(.vertical, AppSpacing.large)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.backward")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(colors.textSecondary)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Atrás")
                } else {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.small)
            .background(colors.backgroundPrimary)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
                .padding(.horizontal, AppSpacing.large)
                .padding(.top, AppSpacing.medium)
                .padding(.bottom, AppSpacing.small)
                .background(
                    LinearGradient(
                        colors: [colors.backgroundPrimary.opacity(0), colors.backgroundPrimary],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.45)
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
        }
        .background(colors.backgroundPrimary.ignoresSafeArea())
    }
}
