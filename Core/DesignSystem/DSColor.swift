import SwiftUI

/// Semantic color accessors backed by adaptive Asset Catalog colors.
/// Never scatter Color(hex:) across views. See docs/03-design-system.md §5 and RULES.md §4.
extension Color {
    enum ds {
        static let canvas = Color("Canvas")
        static let surface = Color("SurfaceElevated")
        static let textPrimary = Color("TextPrimary")
        static let accent = Color("Accent")

        /// Secondary/tertiary text step up one contrast level when "Increase contrast" is on
        /// (this is where the app's low contrast lives — grey previews/labels). See ThemeStore.
        static var textSecondary: Color {
            ContrastState.increased ? Color("TextPrimary") : Color("TextSecondary")
        }
        static var textTertiary: Color {
            ContrastState.increased ? Color("TextSecondary") : Color("TextTertiary")
        }
    }
}
