import SwiftUI
import UIKit

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

    /// The appearance the **keyboard** is born with — always `.light` or `.dark`, **never** `.default`.
    ///
    /// The keyboard is not in the app's window: it lives in its own `UIRemoteKeyboardWindow`, which
    /// inherits none of the `preferredColorScheme` override `AppRootView` applies. `.default` tells
    /// that window "work your own appearance out" — and it works it out from the *device*, not from
    /// As Told. So a reader who picks **Light** on a Dark phone (or **Dark** on a Light one) types on
    /// a keyboard that contradicts the app they are looking at. The Theme picker is a kept setting
    /// (RULES.md §4), and a setting that stops at the edge of the keyboard is only half applied.
    ///
    /// `environment` is the app's *effective* rendered scheme (`@Environment(\.colorScheme)` in the
    /// editor), which already accounts for the override above. Reading the theme first and falling
    /// back to the environment only for `.system` is deliberate: a forced theme answers without
    /// depending on `preferredColorScheme` having propagated yet.
    ///
    /// This is **not** the New Note flicker. A frame-by-frame look at that push (2026-08-20) showed
    /// the keyboard already light on its first visible frame in Light mode — nothing was recolouring.
    /// The artifact was the keyboard taking focus mid-push and sliding in sideways with the editor,
    /// and it is fixed where it happens: `NotePageView.afterNavigationTransition`.
    func keyboardAppearance(inheriting environment: ColorScheme) -> UIKeyboardAppearance {
        switch colorScheme ?? environment {
        case .light: return .light
        case .dark: return .dark
        @unknown default: return .light
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
