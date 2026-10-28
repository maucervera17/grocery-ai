import SwiftUI

struct AgentAvatarView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image("BrandLaunchLogo")
            .resizable()
            .scaledToFit()
            .padding(AppSpacing.small)
            .frame(
                width: AppControlSize.minimumTapTarget,
                height: AppControlSize.minimumTapTarget
            )
            .background(avatarBackground, in: .circle)
            .environment(\.colorScheme, logoColorScheme)
            .accessibilityHidden(true)
    }

    private var avatarBackground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var logoColorScheme: ColorScheme {
        colorScheme == .dark ? .light : .dark
    }
}
