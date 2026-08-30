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
        /// Text/glyphs drawn *on* an accent fill. Not a fixed white: the dark accent is light
        /// enough that white on it would be the low-contrast pairing.
        static let onAccent = Color("OnAccent")

        /// A link's ink. Deliberately not browser blue: a muted teal-blue that reads as a
        /// destination without turning a page of writing into a web page (Quiet Editorial,
        /// docs/03-design-system.md). Measured against both note grounds — 6.6:1 on Canvas and
        /// 7.1:1 on SurfaceElevated in Light, 9.9:1 and 9.0:1 in Dark.
        ///
        /// Colour is never the only signal: links carry VoiceOver link semantics, and gain an
        /// underline when Differentiate Without Color is on (RULES.md §4).
        static let link = Color("Link")

        /// The ground a code block sits on. A quiet tint away from the canvas rather than a panel —
        /// just enough to say "this run of characters is not prose".
        static let codeSurface = Color("CodeSurface")

        /// Syntax colour, for a code card whose fence named a language As Told knows (RULES.md §7,
        /// amended 2026-08-24). Five tokens, because five is what the eye uses to read a snippet, and
        /// each one is measured against `codeSurface` rather than against the canvas — that is the
        /// ground it is actually read on. Light / Dark, in order: 7.7:1 / 8.1:1 keyword, 6.2 / 9.1
        /// string, 5.0 / 5.6 comment, 5.8 / 7.9 number, 6.8 / 8.6 type.
        ///
        /// A comment is the quietest of them on purpose and still clears the 4.5:1 floor every glyph in
        /// this app clears: recede, do not disappear.
        static let codeKeyword = Color("CodeKeyword")
        static let codeString = Color("CodeString")
        static let codeComment = Color("CodeComment")
        static let codeNumber = Color("CodeNumber")
        /// Types, and the names being called. One colour for both: the distinction a scanner can make
        /// reliably is "this name is being used as a thing", not which kind of thing it is.
        static let codeType = Color("CodeType")

        /// Distinct, muted tints for the header action icons (adaptive Light/Dark).
        static let iconProfile = Color("IconProfile")     // terracotta
        static let iconCalendar = Color("IconCalendar")   // sage teal
        static let iconCompose = Color("IconCompose")     // slate blue
    }
}
