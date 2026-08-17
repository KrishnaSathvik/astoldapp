import SwiftUI

/// User-selectable appearance. (V1 originally locked this to system-only; the picker was added
/// intentionally — see RULES.md §1 and docs/03-design-system.md §15.)
enum AppTheme: String, CaseIterable, Identifiable {
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

/// Non-isolated flag read by the semantic color accessors so "Increase contrast" affects the whole
/// tree on the next render. Updated only from the main actor via ThemeStore.
enum ContrastState {
    nonisolated(unsafe) static var increased = false
}

@Observable @MainActor
final class ThemeStore {
    static let themeKey = "appTheme"
    static let contrastKey = "increaseContrast"

    var theme: AppTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }
    var increaseContrast: Bool {
        didSet {
            UserDefaults.standard.set(increaseContrast, forKey: Self.contrastKey)
            ContrastState.increased = increaseContrast
        }
    }

    init(defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: Self.themeKey) ?? AppTheme.system.rawValue
        theme = AppTheme(rawValue: raw) ?? .system
        let contrast = defaults.bool(forKey: Self.contrastKey)
        increaseContrast = contrast
        ContrastState.increased = contrast
    }

    var colorScheme: ColorScheme? { theme.colorScheme }
}
