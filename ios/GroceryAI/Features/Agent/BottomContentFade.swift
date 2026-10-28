import SwiftUI

struct BottomContentFade: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: backgroundColor.opacity(0), location: 0),
                .init(color: backgroundColor.opacity(0.03), location: 0.12),
                .init(color: backgroundColor.opacity(0.12), location: 0.24),
                .init(color: backgroundColor.opacity(0.32), location: 0.38),
                .init(color: backgroundColor.opacity(0.62), location: 0.52),
                .init(color: backgroundColor.opacity(0.88), location: 0.64),
                .init(color: backgroundColor, location: 0.72),
                .init(color: backgroundColor, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : .white
    }
}
