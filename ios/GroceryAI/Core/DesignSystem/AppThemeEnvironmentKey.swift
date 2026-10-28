import SwiftUI

struct AppThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppTheme = .grocery
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeEnvironmentKey.self] }
        set { self[AppThemeEnvironmentKey.self] = newValue }
    }
}
