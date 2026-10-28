import SwiftUI

struct AppTheme {
    let lightColors: AppThemeColors
    let darkColors: AppThemeColors

    func colors(for colorScheme: ColorScheme) -> AppThemeColors {
        switch colorScheme {
        case .dark:
            darkColors
        default:
            lightColors
        }
    }
}

extension AppTheme {
    static let grocery = AppTheme(
        lightColors: AppThemeColors(
            brandPrimary: BarasuPalette.accent,
            brandOnPrimary: .white,
            brandSecondary: BarasuPalette.accent.opacity(0.10),
            backgroundPrimary: .white,
            backgroundSecondary: BarasuPalette.surface,
            cellBackground: BarasuPalette.surface,
            surfacePrimary: .white,
            surfaceElevated: BarasuPalette.surface,
            textPrimary: BarasuPalette.primary,
            textSecondary: BarasuPalette.primary.opacity(0.64),
            borderSubtle: BarasuPalette.neutral,
            statusSuccess: BarasuPalette.success,
            statusWarning: BarasuPalette.alert,
            statusError: Color(red: 0.72, green: 0.12, blue: 0.13),
            statusInformation: BarasuPalette.accent
        ),
        darkColors: AppThemeColors(
            brandPrimary: BarasuPalette.accent,
            brandOnPrimary: .white,
            brandSecondary: BarasuPalette.accent.opacity(0.18),
            backgroundPrimary: Color(uiColor: .systemBackground),
            backgroundSecondary: Color(uiColor: .secondarySystemBackground),
            cellBackground: Color(uiColor: .secondarySystemBackground),
            surfacePrimary: Color(uiColor: .systemBackground),
            surfaceElevated: Color(uiColor: .tertiarySystemBackground),
            textPrimary: .primary,
            textSecondary: .secondary,
            borderSubtle: Color(uiColor: .separator),
            statusSuccess: BarasuPalette.success,
            statusWarning: BarasuPalette.alert,
            statusError: Color(red: 1.00, green: 0.48, blue: 0.48),
            statusInformation: BarasuPalette.accent
        )
    )
}

