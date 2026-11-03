import SwiftUI

struct OnboardingProgressBar: View {
    let progress: Double

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(colors.borderSubtle)
                Capsule()
                    .fill(colors.brandPrimary)
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 6)
        .animation(reduceMotion ? nil : .smooth, value: progress)
        .accessibilityHidden(true)
    }
}
