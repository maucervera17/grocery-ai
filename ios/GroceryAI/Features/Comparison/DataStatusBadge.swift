import SwiftUI

struct DataStatusBadge: View {
    let status: DataStatus

    @Environment(\.appTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = theme.colors(for: colorScheme)

        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, AppSpacing.small)
            .padding(.vertical, AppSpacing.extraSmall)
            .background(color(colors).opacity(0.16), in: .capsule)
            .foregroundStyle(color(colors))
    }

    private var label: String {
        switch status.rawValue {
        case "verified": "Verificado"
        case "stale": "Desactualizado"
        default: "Sin verificar"
        }
    }

    private func color(_ colors: AppThemeColors) -> Color {
        switch status.rawValue {
        case "verified": colors.statusSuccess
        case "stale": colors.statusWarning
        default: colors.statusInformation
        }
    }
}
