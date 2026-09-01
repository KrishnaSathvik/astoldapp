import SwiftUI

/// What a Home row shows, and at what weight, decided before anything is drawn.
///
/// **A body never masquerades as a title** (RULES.md §1, 2026-08-31). The primary/semibold treatment
/// means exactly one thing — *the writer named this note* — and a row earns it only by having a
/// title. A titleless note is drawn as what it is: an excerpt, in secondary body text, with no
/// promoted first line above it. `Untitled`, `Voice Note`, a generated title, and a badge all stay
/// forbidden; the row simply has no title line.
///
/// Pure and separate from the view, because this is a hierarchy bug that renders perfectly: a
/// transcript's opening sentence in primary semibold looks like a heading somebody chose, and a
/// column of voice captures then reads as a wall of names nobody wrote.
struct NoteRowContent: Equatable {
    /// The title the writer chose, or `nil` when there is none. Never substituted.
    let title: String?
    /// The body as an excerpt — the lines the reader would have seen, flattened onto one string and
    /// allowed to wrap. Under the title when there is one; the **whole row** when there is not.
    let preview: String

    var isTitled: Bool { title != nil }

    /// Body size for a titleless note, `subheadline` under a title.
    ///
    /// The excerpt is the row's entire content when there is no title, so it reads at body size —
    /// large enough to be the thing you are looking at, and still plainly not a heading, because
    /// weight and colour are what a heading is made of here. Under a real title it steps down to
    /// `subheadline`, which is the supporting role it has always had.
    var previewFont: Font { isTitled ? .ds.preview : .ds.noteBody }

    /// Two lines either way (2026-08-31, up from one).
    ///
    /// One line made a titleless row a single orphaned sentence that looked like a headline and left
    /// the section sparse. Two makes it read as an excerpt — and gives a titled note's preview room
    /// to say something as well. Deterministic: the limit is the same for every row, so truncation
    /// never depends on what happens to fit.
    static let previewLineLimit = 2

    /// `lines` is the body as the reader would have seen it, already flattened.
    ///
    /// The preview is the **whole** body in both cases. A titleless note no longer spends its first
    /// line on a promoted primary, so nothing is dropped from the excerpt to pay for a title the
    /// writer never wrote.
    static func make(title: String?, lines: [String]) -> NoteRowContent {
        // Joined with two spaces rather than a separator glyph: a checklist reads as
        // `☑ Website  ☐ Screenshots`, and a punctuation mark between every line would be structure
        // the note does not contain.
        NoteRowContent(title: normalizedTitle(title), preview: lines.joined(separator: "  "))
    }
}

/// Chromeless Home row: an optional title over a two-line body excerpt.
///
/// A titled note is three lines at most and lands around 76–84 pt; a titleless one is two and stays
/// shorter. That difference is deliberate — a titled note genuinely has more to show, and forcing
/// both to one height is what previously cost the excerpt its second line (RULES.md §1, §4;
/// docs/03-design-system.md §4.3).
struct NoteRow: View {
    let note: Note

    /// The body as the reader sees it, line by line — hidden structure markers replaced by the
    /// visible ones, a table by its cells rather than the pipes it is stored in, a code block by its
    /// code rather than its fences (RULES.md §4).
    private var content: NoteRowContent {
        .make(title: note.title, lines: StructuredTextExport.previewLines(note.body))
    }

    var body: some View {
        let content = content
        VStack(alignment: .leading, spacing: DSSpacing.s1) {
            // Drawn only when the writer wrote one. This `if` is the whole rule.
            if let title = content.title {
                Text(title)
                    .font(.ds.noteTitle)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
            }

            // A note with nothing to say draws no excerpt at all rather than an empty line —
            // reserving the space would mean putting an invisible character in a note, and nothing
            // goes into a note that the writer did not.
            if !content.preview.isEmpty {
                Text(content.preview)
                    .font(content.previewFont)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineLimit(NoteRowContent.previewLineLimit)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, DSSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// What the row *says*, which is not what it shows. `previewLines` draws the glyphs a reader would
    /// have seen on the page; a reader who cannot see them needs the words those glyphs stand for
    /// (`StructuredTextExport.spokenRow`).
    private var accessibilityText: String {
        StructuredTextExport.spokenRow(title: normalizedTitle(note.title), body: note.body)
    }
}
