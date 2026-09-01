import SwiftUI

/// Dynamic Type-backed semantic type roles. System San Francisco only (no custom UI font).
/// See docs/03-design-system.md §6 and RULES.md §4.
extension Font {
    enum ds {
        static let homeTitle = Font.system(.largeTitle, weight: .bold)      // "Today"
        static let screenTitle = Font.system(.title, weight: .bold)         // "Settings"
        static let groupTitle = Font.system(.title3, weight: .semibold)     // Yesterday / date group
        static let noteTitle = Font.system(.body, weight: .semibold)        // Home row title
        /// A **titleless** note's excerpt on a Home row — the whole row, since there is no title.
        ///
        /// **Regular at body size** (2026-08-31). Semibold and then medium were both tried, and both
        /// were the same mistake in different amounts: any extra weight on a body line reads as a
        /// heading, and a column of voice transcripts then looks like a list of names nobody wrote.
        /// Size carries the emphasis instead — it is the row's entire content, so it reads at body
        /// size, drawn in `textSecondary` so it stays plainly subordinate to a title somebody chose
        /// without ever looking disabled (RULES.md §1).
        static let noteBody = Font.system(.body)                             // titleless Home row
        static let editorTitle = Font.system(.title2, weight: .semibold)    // editor title field
        static let editorBody = Font.system(.body)                          // main writing
        static let preview = Font.system(.subheadline)                      // body preview
        static let dateLabel = Font.system(.caption, weight: .semibold)     // top date
        static let caption = Font.system(.caption)
    }
}
