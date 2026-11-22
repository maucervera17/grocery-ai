import SwiftUI

struct OnboardingScaffold<Footer: View, Content: View>: View {
    enum Layout {
        case top
        case centered
    }

    let step: OnboardingStep
    var title: String?
    var subtitle: String?
    var onBack: (() -> Void)?
    var layout: Layout = .top
    let footer: Footer
    let content: Content

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    init(
        step: OnboardingStep,
        title: String? = nil,
        subtitle: String? = nil,
        onBack: (() -> Void)? = nil,
        layout: Layout = .top,
        @ViewBuilder footer: @escaping () -> Footer,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.step = step
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.layout = layout
        self.footer = footer()
        self.content = content()
    }

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        VStack(spacing: 0) {
            header

            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.extraLarge) {
                        if let title {
                            VStack(alignment: .leading, spacing: AppSpacing.small) {
                                Text(title)
                                    .font(.title.weight(.semibold))
                                    .foregroundStyle(colors.textPrimary)
                                if let subtitle {
                                    Text(subtitle)
                                        .font(AppTypography.body)
                                        .foregroundStyle(colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }

                        content
                    }
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: frameAlignment)
                    .padding(.horizontal, AppSpacing.extraLarge)
                    .padding(.top, AppSpacing.medium)
                    .padding(.bottom, AppSpacing.extraLarge)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(colors.backgroundPrimary)
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, AppSpacing.extraLarge)
                .padding(.vertical, AppSpacing.medium)
                .frame(maxWidth: .infinity)
                .background {
                    // Opaque behind the controls so scrolled options never show
                    // through a disabled button; a short fade sits just above.
                    if Footer.self != EmptyView.self {
                        colors.backgroundPrimary
                            .ignoresSafeArea(edges: .bottom)
                            .overlay(alignment: .top) {
                                BottomContentFade()
                                    .frame(height: AppSpacing.section)
                                    .offset(y: -AppSpacing.section)
                            }
                    }
                }
        }
        .overlay(alignment: .leading) {
            if let onBack, step.showsBackButton {
                edgeSwipeBack(onBack)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            OnboardingEvent.stepViewed(step).log()
        }
    }

    /// Hiding the navigation bar disables the system swipe-back, so a thin
    /// leading-edge strip restores it for steps that show the back button.
    private func edgeSwipeBack(_ onBack: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: AppSpacing.large)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: AppSpacing.small)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        if horizontal > 60, abs(value.translation.height) < horizontal {
                            onBack()
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private var frameAlignment: Alignment {
        layout == .centered ? .center : .top
    }

    @ViewBuilder
    private var header: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(spacing: AppSpacing.medium) {
            if let onBack, step.showsBackButton {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(colors.textSecondary)
                        .frame(width: AppControlSize.minimumTapTarget, height: AppControlSize.minimumTapTarget)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Atrás")
            } else {
                Spacer()
                    .frame(width: AppControlSize.minimumTapTarget)
            }

            if step.progressIndex != nil {
                OnboardingProgressBar(progress: step.progressFraction)
                    .accessibilityElement()
                    .accessibilityLabel(step.accessibilityStepAnnouncement ?? "")
            }
        }
        .frame(height: AppControlSize.minimumTapTarget)
        .padding(.horizontal, AppSpacing.large)
    }
}
