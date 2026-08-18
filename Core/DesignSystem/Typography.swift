import SwiftUI

/// Dynamic Type-backed semantic type roles. System San Francisco only (no custom UI font).
/// See docs/03-design-system.md §6 and RULES.md §4.
extension Font {
    enum ds {
        static let homeTitle = Font.system(.largeTitle, weight: .bold)      // "Today"
        static let screenTitle = Font.system(.title, weight: .bold)         // "Settings"
        static let groupTitle = Font.system(.title3, weight: .semibold)     // Yesterday / date group
        static let noteTitle = Font.system(.body, weight: .semibold)        // Home row title
        static let noteBody = Font.system(.body)                            // untitled Home row
        static let editorTitle = Font.system(.title2, weight: .semibold)    // editor title field
        static let editorBody = Font.system(.body)                          // main writing
        static let preview = Font.system(.subheadline)                      // body preview
        static let dateLabel = Font.system(.caption, weight: .semibold)     // top date
        static let caption = Font.system(.caption)
    }
}
