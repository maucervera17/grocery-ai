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
            brandSecondary: Color(red: 0.10, green: 0.25, blue: 0.16),
            backgroundPrimary: Color(red: 0.05, green: 0.07, blue: 0.06),
            backgroundSecondary: Color(red: 0.09, green: 0.12, blue: 0.10),
            surfacePrimary: Color(red: 0.11, green: 0.14, blue: 0.12),
            surfaceElevated: Color(red: 0.15, green: 0.18, blue: 0.16),
            textPrimary: Color(red: 0.94, green: 0.96, blue: 0.95),
            textSecondary: Color(red: 0.69, green: 0.74, blue: 0.71),
            borderSubtle: Color(red: 0.27, green: 0.32, blue: 0.29),
            statusSuccess: Color(red: 0.35, green: 0.82, blue: 0.52),
            statusWarning: Color(red: 0.96, green: 0.68, blue: 0.25),
            statusError: Color(red: 1.00, green: 0.48, blue: 0.48),
            statusInformation: Color(red: 0.45, green: 0.68, blue: 1.00)
        )
    )
}

