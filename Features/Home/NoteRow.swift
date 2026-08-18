import SwiftUI

/// Chromeless Home row: title + preview, or body-only when no title. Never renders "Untitled".
/// Editorial hierarchy — restrained semibold title, lighter preview with comfortable leading; an
/// untitled note's first meaningful line *is* its primary content, so it reads at body weight.
/// See docs/03-design-system.md §4.3 and RULES.md §4.
struct NoteRow: View {
    let note: Note
    private var displayTitle: String? { normalizedTitle(note.title) }

    /// The body as the reader sees it — hidden structure markers replaced by the visible ones (RULES.md
    /// §4) — with leading blank lines dropped, so a note that starts with a newline still shows its first
    /// real words instead of an empty preview.
    private var previewText: String {
        String(StructuredTextExport.plainText(note.body).drop(while: { $0 == "\n" || $0 == "\r" }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            if let displayTitle {
                Text(displayTitle)
                    .font(.ds.noteTitle)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
                Text(previewText)
                    .font(.ds.preview)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(3)
            } else {
                Text(previewText)
                    .font(.ds.noteBody)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineSpacing(2)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if let displayTitle { return "\(displayTitle). \(previewText)" }
        return previewText
    }
}
