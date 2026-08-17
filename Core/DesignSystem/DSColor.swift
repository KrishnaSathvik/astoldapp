import SwiftUI

/// Semantic color accessors backed by adaptive Asset Catalog colors.
/// Never scatter Color(hex:) across views. See docs/03-design-system.md §5 and RULES.md §4.
extension Color {
    enum ds {
        static let canvas = Color("Canvas")
        static let surface = Color("SurfaceElevated")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textTertiary = Color("TextTertiary")
        static let accent = Color("Accent")

        /// Distinct, muted tints for the header action icons (adaptive Light/Dark).
        static let iconProfile = Color("IconProfile")     // terracotta
        static let iconCalendar = Color("IconCalendar")   // sage teal
        static let iconCompose = Color("IconCompose")     // slate blue
    }
}
