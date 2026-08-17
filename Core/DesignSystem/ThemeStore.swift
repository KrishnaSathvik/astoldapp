import SwiftUI

/// User-selectable appearance. (V1 originally locked this to system-only; the picker was added
/// intentionally — see RULES.md §1 and docs/03-design-system.md §15.)
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case light, dark, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "Use device settings"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil   // follow the system
        }
    }
}

@Observable @MainActor
final class ThemeStore {
    static let themeKey = "appTheme"

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }

    init(defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: Self.themeKey) ?? AppTheme.system.rawValue
        theme = AppTheme(rawValue: raw) ?? .system
    }

    var colorScheme: ColorScheme? { theme.colorScheme }
}
