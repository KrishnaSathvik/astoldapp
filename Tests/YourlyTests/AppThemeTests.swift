import Testing
import SwiftUI
import UIKit
@testable import Yourly

/// The theme has to be mapped onto *two* surfaces, and the second one must never be left to guess.
///
/// `AppRootView` applies `preferredColorScheme` to the app's window, and that is where the mapping used
/// to stop. The keyboard is not in that window — it lives in its own `UIRemoteKeyboardWindow`, which
/// inherits none of the override. `.default` tells that window to work its own appearance out, and it
/// works it out from the *device*: pick Light on a Dark phone and the app goes light while the
/// keyboard stays dark. The Theme picker is a kept setting, so it has to reach the keyboard too.
struct AppThemeTests {

    /// The invariant, and the whole point of the change: whatever the theme and whatever the
    /// environment, the keyboard is told outright. `.default` means "you decide", and what it decides
    /// from is the device — which is precisely the setting the reader has just overridden.
    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func noThemeEverLeavesTheKeyboardToDecideForItself(environment: ColorScheme) {
        for theme in AppTheme.allCases {
            #expect(theme.keyboardAppearance(inheriting: environment) != .default,
                    "\(theme) leaves the keyboard to resolve its own appearance")
        }
    }

    /// A forced theme answers on its own, without waiting for `preferredColorScheme` to reach the
    /// environment: a Light app must say `.light` even while the environment still reads Dark.
    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func aForcedThemeDoesNotDependOnTheEnvironment(environment: ColorScheme) {
        #expect(AppTheme.light.keyboardAppearance(inheriting: environment) == .light)
        #expect(AppTheme.dark.keyboardAppearance(inheriting: environment) == .dark)
    }

    /// And "Use device settings" resolves to a real appearance from the scheme the app is actually
    /// rendering in — not to `.default`, and not to a guess.
    @Test func followTheDeviceTakesTheEffectiveScheme() {
        #expect(AppTheme.system.keyboardAppearance(inheriting: .light) == .light)
        #expect(AppTheme.system.keyboardAppearance(inheriting: .dark) == .dark)
    }

    /// The app and its keyboard never contradict each other: a Light app must not raise a Dark keyboard.
    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func theAppAndTheKeyboardNeverDisagree(environment: ColorScheme) {
        for theme in AppTheme.allCases {
            let effective = theme.colorScheme ?? environment
            let keyboard = theme.keyboardAppearance(inheriting: environment)
            switch effective {
            case .light: #expect(keyboard == .light, "\(theme) renders Light but raises a \(keyboard) keyboard")
            case .dark: #expect(keyboard == .dark, "\(theme) renders Dark but raises a \(keyboard) keyboard")
            @unknown default: Issue.record("\(theme) resolved to a scheme with no keyboard mapping")
            }
        }
    }
}
