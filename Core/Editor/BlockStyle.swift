import Foundation

// The vocabulary of the Style control (`docs/02-features.md` Milestone B2): the six structures a
// writer can reach by tapping, which are exactly the six they can reach by typing a marker or
// speaking a command. Three input methods, one set of structures, one `DocumentAction` underneath.
//
// This is deliberately *not* `BlockKind`. `BlockKind` carries per-line state a menu has no business
// showing — which number a numbered item holds, whether a box is ticked — so a control built on it
// would have to invent a number and a tick state to name a style at all. `BlockStyle` is the name;
// `DocumentAction.setBlockKindEdit` resolves the state per line.

/// A structure a writer can choose by name. Nothing else joins this list: bold, italic, colors, and
/// alignment are inline rich text, which RULES.md §7 puts on the do-not-build list.
enum BlockStyle: String, CaseIterable, Identifiable, Equatable {
    case normal
    case heading
    case subheading
    case bullet
    case numbered
    case checklist

    var id: String { rawValue }

    /// The menu label. Matches the names the writing-help reference already uses, so the same
    /// structure is never called two different things in two surfaces.
    var name: String {
        switch self {
        case .normal: return "Normal"
        case .heading: return "Heading"
        case .subheading: return "Subheading"
        case .bullet: return "Bullet list"
        case .numbered: return "Numbered list"
        case .checklist: return "Checklist"
        }
    }

    /// The kind to apply. The numbered case names 1 and the checklist case unticked only as a
    /// starting point — `DocumentAction.setBlockKindEdit` renumbers from the surrounding list and
    /// preserves an existing tick, because only it can see the lines around the selection.
    var kind: BlockKind {
        switch self {
        case .normal: return .paragraph
        case .heading: return .heading
        case .subheading: return .subheading
        case .bullet: return .bullet
        case .numbered: return .numbered(1)
        case .checklist: return .checklist(checked: false)
        }
    }

    /// The style a line of this kind is showing — the inverse of `kind`, discarding the per-line
    /// state. `4.` and `1.` are both Numbered list; a ticked and an unticked box are both Checklist.
    init(_ kind: BlockKind) {
        switch kind {
        case .paragraph: self = .normal
        case .heading: self = .heading
        case .subheading: self = .subheading
        case .bullet: self = .bullet
        case .numbered: self = .numbered
        case .checklist: self = .checklist
        }
    }

    /// The style the menu should show a checkmark against, or `nil` when the selection spans lines of
    /// more than one style.
    ///
    /// `nil` rather than "whatever the first line is" on purpose: a checkmark is a claim about what
    /// the selection *is*, and a mixed selection is not any one style. Showing none is the honest
    /// answer, and picking a style from that state still converts every selected line.
    static func current(in text: String, selection: NSRange) -> BlockStyle? {
        let doc = MarkupDocument(text)
        let styles = doc.lineIndices(touchedBy: selection).map { BlockStyle(doc.lines[$0].kind) }
        guard let first = styles.first, styles.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
}
