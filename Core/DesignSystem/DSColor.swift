import SwiftUI

/// Semantic color accessors backed by adaptive Asset Catalog colors.
/// Never scatter Color(hex:) across views. See docs/03-design-system.md §5 and RULES.md §4.
extension Color {
    enum ds {
        /// The writing/content ground: plain white on plain black. Neutralised 2026-08-30 from the
        /// warm `#F8F7F3` — see RULES.md §4. Nothing on a content surface carries brand colour now.
        static let canvas = Color("Canvas")

        /// The ground a *grouped* list sits on, which is not the ground a page of writing sits on.
        /// Home, the calendar's day list, and search results draw rows on `surface` islands; those
        /// islands need something to be islands against, and a writing page needs the opposite —
        /// nothing between the words and the screen. One token could not be both.
        static let groupedCanvas = Color("GroupedCanvas")

        static let surface = Color("SurfaceElevated")

        /// A hairline between rows inside one grouped surface. Previously spelled
        /// `textTertiary.opacity(0.16)` at each call site, which made a divider a shade of *text*.
        static let separator = Color("Separator")
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

        /// Distinct, muted tints for the four header action glyphs (adaptive Light/Dark).
        ///
        /// **Monochrome is a rule about content, not about navigation** (restored 2026-08-31, after
        /// a day drawn in `textPrimary`). Home's grounds, note surfaces, text and dividers stay
        /// neutral; the header does not. Four identically-inked glyphs in one corner have to be read
        /// before they can be told apart, and colour here is what makes each one recognisable by
        /// position and hue at a glance — navigation recognition rather than decoration.
        ///
        /// Voice has its own tint rather than sharing compose's: writing and speaking are the two
        /// ways into a note and are peers, so drawing one as the other's second button was the
        /// header saying they were the same control.
        static let iconProfile = Color("IconProfile")     // terracotta
        static let iconCalendar = Color("IconCalendar")   // sage teal
        static let iconCompose = Color("IconCompose")     // slate blue
        static let iconVoice = Color("IconVoice")         // muted lavender

        /// The calendar's own accent — the sage the Calendar glyph wears, used on the calendar page
        /// for every piece of interaction state: the month chevrons, the selected day's fill, today's
        /// ring, and the note-density dots. One colour, so the page reads as belonging to the icon
        /// that opened it, and so a dot **means something** rather than decorating.
        ///
        /// **Not `iconCalendar` itself, and the difference is measured, not taste.** The glyph's sage
        /// (`#4E8A76`) is 4.02:1 against white — fine for a symbol, below the **4.5:1 floor every
        /// glyph in this app clears** (§4) the moment a day *number* is drawn on top of it. This is
        /// the same hue 12% darker in Light: **5.01:1** with `onAccent`. Dark is unchanged from the
        /// glyph's (`#86BCA9`), which already measures 8.8:1 against `onAccent` there — a light
        /// accent needs dark text, which is exactly what `onAccent` exists to provide.
        static let calendarAccent = Color("CalendarAccent")
    }
}
