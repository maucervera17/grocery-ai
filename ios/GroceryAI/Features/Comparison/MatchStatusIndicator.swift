import SwiftUI

struct MatchStatusIndicator: View {
    let isAlternative: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        Image(systemName: isAlternative ? "circle" : "circle.fill")
            .font(.caption)
            .foregroundStyle(isAlternative ? colors.statusWarning : colors.statusSuccess)
            .accessibilityLabel(isAlternative ? "Producto alternativo" : "Coincidencia exacta")
    }
}
