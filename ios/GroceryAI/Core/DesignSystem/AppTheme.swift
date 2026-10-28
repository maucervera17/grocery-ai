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
            brandPrimary: Color(red: 0.08, green: 0.45, blue: 0.25),
            brandOnPrimary: .white,
            brandSecondary: Color(red: 0.88, green: 0.96, blue: 0.91),
            backgroundPrimary: Color(red: 0.97, green: 0.98, blue: 0.97),
            backgroundSecondary: Color(red: 0.93, green: 0.95, blue: 0.94),
            cellBackground: Color(uiColor: .secondarySystemBackground),
            surfacePrimary: .white,
            surfaceElevated: .white,
            textPrimary: Color(red: 0.08, green: 0.10, blue: 0.09),
            textSecondary: Color(red: 0.35, green: 0.39, blue: 0.37),
            borderSubtle: Color(red: 0.82, green: 0.85, blue: 0.83),
            statusSuccess: Color(red: 0.08, green: 0.45, blue: 0.25),
            statusWarning: Color(red: 0.67, green: 0.38, blue: 0.03),
            statusError: Color(red: 0.72, green: 0.12, blue: 0.13),
            statusInformation: Color(red: 0.10, green: 0.36, blue: 0.66)
        ),
        darkColors: AppThemeColors(
            brandPrimary: Color(red: 0.35, green: 0.82, blue: 0.52),
            brandOnPrimary: Color(red: 0.03, green: 0.13, blue: 0.07),
            brandSecondary: Color(uiColor: .secondarySystemBackground),
            backgroundPrimary: Color(uiColor: .systemBackground),
            backgroundSecondary: Color(uiColor: .secondarySystemBackground),
            cellBackground: Color(uiColor: .secondarySystemBackground),
            surfacePrimary: Color(uiColor: .systemBackground),
            surfaceElevated: Color(uiColor: .tertiarySystemBackground),
            textPrimary: .primary,
            textSecondary: .secondary,
            borderSubtle: Color(uiColor: .separator),
            statusSuccess: Color(red: 0.35, green: 0.82, blue: 0.52),
            statusWarning: Color(red: 0.96, green: 0.68, blue: 0.25),
            statusError: Color(red: 1.00, green: 0.48, blue: 0.48),
            statusInformation: Color(red: 0.45, green: 0.68, blue: 1.00)
        )
    )
}

