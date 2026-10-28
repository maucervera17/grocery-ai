import SwiftUI

struct MatchStatusLegend: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        HStack(spacing: AppSpacing.large) {
            Label("Exacto", systemImage: "circle.fill")
                .foregroundStyle(colors.statusSuccess)

            Label("Alternativa", systemImage: "circle")
                .foregroundStyle(colors.statusWarning)
        }
        .font(.footnote)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verde: coincidencia exacta. Amarillo: producto alternativo")
    }
}
