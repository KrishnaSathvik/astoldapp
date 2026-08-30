import UIKit
import SwiftUI

// TextKit 1 rendering for the structured editor (R1a): the UITextView's backing store holds the raw
// source string (with markers) so native editing, IME/marked-text composition, and autocorrect keep
// working for Telugu/Hindi/code-switch input. Markers are *hidden* at the glyph layer and the visible
// list markers (•, 1., ☐/☑) are drawn in a left gutter. See docs/02-features.md (Milestone A) and
// RULES.md §1 (no formatting ribbon; structure must not dominate).

extension NSAttributedString.Key {
    /// Marks a marker-prefix range whose glyphs must be hidden (zero-width) by the layout manager.
    static let astHiddenMarker = NSAttributedString.Key("astHiddenMarker")
    /// Marks every line of a table block while its **source** is on screen — that is, while the note is
    /// being edited — so the page can draw the quiet container that groups those lines into one table.
    static let astTableBlock = NSAttributedString.Key("astTableBlock")
    /// Marks every line of a code block while its **source** is on screen, so the page can draw the
    /// quiet ground that groups those lines into one block.
    static let astCodeBlock = NSAttributedString.Key("astCodeBlock")
    /// Carries a link's destination on the run the reader can see and tap. The hidden syntax around it
    /// is marked `astHiddenMarker` like any other marker — a destination is not a glyph.
    static let astLink = NSAttributedString.Key("astLink")
}

enum StructuredTextStyle {
    /// Left gutter width for lists; content and drawn markers align to this.
    static let listIndent: CGFloat = 28
    static let lineSpacing: CGFloat = 4

    /// How far from the left edge a tap still means "tick this item".
    ///
    /// Wider than the gutter the box is *drawn* in, and deliberately so: the box stays small because a
    /// marker is not the sentence, but the target has to clear the ~44 points RULES.md §4 asks of a
    /// primary control, and ticking things off is the whole point of a checklist. The overhang past
    /// `listIndent` covers roughly the item's first character — the trade is honest, because a missed
    /// tap costs a caret and a raised keyboard, and only a checklist line claims it at all.
    static let checkboxHitWidth: CGFloat = 44

    /// How tall that target is, measured through the item's own line.
    ///
    /// A checklist row is a line of body text — about 24 points at the default text size — so the
    /// gutter on its own gave the box a 44×24 target, barely half the area §4 asks for. The band is
    /// grown to this height *around* the line instead, and because the bands of neighbouring items
    /// then overlap, one rule decides every touch inside one: see
    /// `BodyTextView.Coordinator.checkboxLine(in:at:)`. A touch inside an item's own line is always
    /// that item's; anywhere else the nearest item wins, and ties go to the earlier one.
    ///
    /// Growing the *line* to 44 points was the other way out, and it is the wrong one here. It would
    /// add twenty points to every checklist row — a six-item list would take eighty percent more page
    /// than the paragraphs around it — and a checklist item is a sentence the writer wrote, not a row
    /// in a task table (docs/03-design-system.md).
    static let checkboxHitHeight: CGFloat = 44

    static func bodyFont() -> UIFont { UIFont.preferredFont(forTextStyle: .body) }

    /// The font a line of this kind is set in.
    ///
    /// Exhaustive on purpose, with no `default:` case. Bullet, numbered, and checklist lines are
    /// **body text** — the same face, size, and Dynamic Type scaling as an ordinary paragraph, because
    /// a list item is a sentence the writer wrote, not an annotation on one. Only heading and
    /// subheading depart from body type, and a seventh kind arriving here has to say which it is
    /// rather than inheriting a silent fallthrough.
    static func font(for kind: BlockKind) -> UIFont {
        switch kind {
        case .heading: return headingFont()
        case .subheading: return subheadingFont()
        case .paragraph, .bullet, .numbered, .checklist: return bodyFont()
        }
    }

    static func headingFont() -> UIFont { scaled(.title2, weight: .semibold) }

    /// Body size, heavier weight. Deliberately *not* a second large size: at `.title3` a subheading
    /// sat two points under a heading at the same weight, so the two structures were indistinguishable
    /// on the page and the choice between them meant nothing. Size carries "heading", weight carries
    /// "subheading", and the ladder reads 22-semibold / 17-semibold / 17-regular.
    static func subheadingFont() -> UIFont { UIFont.preferredFont(forTextStyle: .headline) }

    /// A table's heading row: body size, heavier weight. Column headings are labels for the words under
    /// them, so they take the same weight a subheading does without leaving body size — a table that
    /// shouted its headings would be louder than the note it sits in.
    static func tableHeaderFont() -> UIFont { scaled(.body, weight: .semibold) }

    /// The line under a table preview — "9 rows · 7 columns", and the way into the full grid.
    static func tableFooterFont() -> UIFont { UIFont.preferredFont(forTextStyle: .footnote) }

    /// The page chrome above the first line — the note's title and its creation date.
    ///
    /// `UIFont` twins of the SwiftUI tokens `.ds.editorTitle` and `.ds.dateLabel`: same text styles,
    /// same weights, same Dynamic Type scaling. They live here because the date and title moved into
    /// UIKit when they became part of the body's scroll (docs/03-design-system.md §12, `NotePageView`).
    static func editorTitleFont() -> UIFont { scaled(.title2, weight: .semibold) }
    static func dateLabelFont() -> UIFont { scaled(.caption1, weight: .semibold) }

    /// Space above a heading. A heading is a section break, and heavier type alone does not read as
    /// one when it is jammed against the paragraph above it. Derived from the body line height so it
    /// tracks Dynamic Type, and never applied to the first line, which has the page edge above it.
    static func spacingBefore(_ kind: BlockKind) -> CGFloat {
        switch kind {
        case .heading: return bodyFont().lineHeight * 0.75
        case .subheading: return bodyFont().lineHeight * 0.55
        case .checklist: return checklistLeading / 2
        case .paragraph, .bullet, .numbered: return 0
        }
    }

    /// Space *after* a line. Only a checklist item asks for any, and only for the reason below.
    static func spacingAfter(_ kind: BlockKind) -> CGFloat {
        switch kind {
        case .checklist: return checklistLeading / 2
        case .paragraph, .bullet, .numbered, .heading, .subheading: return 0
        }
    }

    /// The extra leading a checklist item carries so its row is a 44-point touch target.
    ///
    /// A checkbox is a control, and a control gets `checkboxHitHeight` (RULES.md §4). Everything else
    /// on the page is prose, which does not. Split evenly above and below, so the words stay centred
    /// in their row and a run of items keeps an even rhythm rather than drifting towards the item
    /// below. Derived from the body line height, so it tracks Dynamic Type and reaches zero on its own
    /// at the text sizes where a line is already 44 points tall.
    static var checklistLeading: CGFloat {
        max(0, checkboxHitHeight - (bodyFont().lineHeight + lineSpacing))
    }

    private static func scaled(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        let descriptor = base.fontDescriptor.addingAttributes(
            [.traits: [UIFontDescriptor.TraitKey.weight: weight]]
        )
        return UIFont(descriptor: descriptor, size: 0)
    }

    static func isList(_ kind: BlockKind) -> Bool { kind.isList }

    /// Every attribute a line of this kind carries. One definition, used by both the styler (which
    /// writes it into the text storage) and the text view's `typingAttributes` (which is the only
    /// thing that can describe an *empty last line*, because it has no characters to hold attributes).
    /// Two nearly-identical copies of this is exactly how the caret ends up styled as one kind of line
    /// while the text around it is another.
    static func attributes(for kind: BlockKind, isFirstLine: Bool,
                           textColor: UIColor) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        // Never on the first line, which has the page edge above it rather than a paragraph.
        if !isFirstLine { paragraph.paragraphSpacingBefore = spacingBefore(kind) }
        paragraph.paragraphSpacing = spacingAfter(kind)
        if isList(kind) {
            paragraph.firstLineHeadIndent = listIndent
            paragraph.headIndent = listIndent
        }
        return [.font: font(for: kind), .paragraphStyle: paragraph, .foregroundColor: textColor]
    }
}

/// Applies fonts, paragraph indentation, and the hidden-marker attribute to a text storage, driven by
/// the parsed source. Only attributes change — never the characters — so this is safe to run after every
/// edit without disturbing IME composition.
enum StructuredTextStyler {
    /// - Parameter tableCards: the height to reserve for each table that is being drawn as a card,
    ///   keyed by the lines it occupies. Empty while the note is being edited, which is what puts the
    ///   canonical source back on screen for the one person entitled to see it — the person editing it.
    ///
    /// - Parameter underlinesLinks: whether a link carries an underline as well as its colour. Driven
    ///   by Differentiate Without Color: colour alone may not be the only thing telling a reader that
    ///   these words go somewhere (RULES.md §4).
    static func apply(to storage: NSTextStorage, textColor: UIColor,
                      secondaryColor: UIColor = .secondaryLabel,
                      linkColor: UIColor = .link,
                      availableWidth: CGFloat = 0,
                      tableCards: [ClosedRange<Int>: CGFloat] = [:],
                      codeCards: [ClosedRange<Int>: CGFloat] = [:],
                      codeTokens: [CodeHighlighting.Token: UIColor] = [:],
                      underlinesLinks: Bool = false) {
        let text = storage.string
        let doc = MarkupDocument(text)
        let full = NSRange(location: 0, length: (text as NSString).length)

        storage.beginEditing()
        storage.removeAttribute(.astHiddenMarker, range: full)
        storage.removeAttribute(.astTableBlock, range: full)
        storage.removeAttribute(.astCodeBlock, range: full)
        storage.removeAttribute(.astLink, range: full)
        storage.removeAttribute(.underlineStyle, range: full)

        for (index, line) in doc.lines.enumerated() {
            // The line's own characters *plus its terminating newline*. A newline belongs to the
            // paragraph it ends, and including it is what lets an **empty** line be styled at all: an
            // empty line's only character is that newline, so styling just `sourceRange` (which is
            // zero-length there) writes nothing and the line silently keeps whatever paragraph style
            // the character had in its previous life — the list indent it was just demoted out of.
            let lineEnd = line.sourceRange.location + line.sourceRange.length
            let styled = NSRange(location: line.sourceRange.location,
                                 length: line.sourceRange.length + (lineEnd < full.length ? 1 : 0))

            storage.addAttributes(
                StructuredTextStyle.attributes(for: line.kind, isFirstLine: index == 0,
                                               textColor: textColor),
                range: styled
            )

            if line.markerLength > 0 {
                let markerRange = NSRange(location: line.sourceRange.location, length: line.markerLength)
                storage.addAttribute(.astHiddenMarker, value: true, range: markerRange)
            }

            // A link's bracket and destination are hidden exactly the way a block marker is; what is
            // left is the words, in the link colour, carrying the destination for the tap.
            for link in line.links {
                for run in link.hiddenRuns {
                    storage.addAttribute(.astHiddenMarker, value: true, range: run)
                }
                let visible = link.displayRange
                guard visible.length > 0, NSMaxRange(visible) <= full.length else { continue }
                storage.addAttribute(.foregroundColor, value: linkColor, range: visible)
                storage.addAttribute(.astLink, value: link.destination, range: visible)
                if underlinesLinks {
                    storage.addAttribute(.underlineStyle,
                                         value: NSUnderlineStyle.single.rawValue, range: visible)
                    storage.addAttribute(.underlineColor, value: linkColor, range: visible)
                }
            }
        }

        // Both presentations, in one pass. Per-block editing means a note can hold a table the caret
        // is inside — showing its source — and another table three lines down that is still a card, so
        // "cards or source" was never a property of the note: it is a property of each block. Deciding
        // it for the whole note left the block being edited with none of its editing presentation the
        // moment a second block of the same kind was on the page (RULES.md §7, amended 2026-08-23).
        styleTableSource(in: storage, doc: doc, secondaryColor: secondaryColor,
                         drawnAsCards: Set(tableCards.keys))
        reserveCards(in: storage, doc: doc, heights: tableCards, full: full)

        styleCodeSource(in: storage, doc: doc, secondaryColor: secondaryColor,
                        tokens: codeTokens, full: full, drawnAsCards: Set(codeCards.keys))
        reserveCards(in: storage, doc: doc, heights: codeCards, full: full)
        storage.endEditing()
    }

    /// Editing: a code block that still looks like code.
    ///
    /// Until 2026-08-24 this showed the fences, recessed to the colour of punctuation. That was honest
    /// about the storage and wrong about the note: tapping a code card replaced it with ```` ```python ````
    /// and a wall of unstyled text, so the block a reader had been looking at visibly broke the moment
    /// they touched it. The fences are storage — exactly like a table's `| --- |` row — and a reader
    /// should never have to look past them (RULES.md §7, amended 2026-08-24).
    ///
    /// So the block keeps its ground, its monospaced face, its language label and its syntax colour the
    /// whole time, and only the two fence lines give up their glyphs:
    ///
    ///  - the **opening** fence keeps the air above the block, the header `CodeBlockView` draws the
    ///    language and Copy Code into, and the card's own top padding. It has no glyphs, so nothing of
    ///    ```` ```python ```` is drawn.
    ///  - the **closing** fence keeps the block's bottom padding and the air below it.
    ///  - everything between them is ordinary, editable, syntax-coloured text in the text view itself.
    ///    No second editor, no sheet, no separate document — the note is still one string being typed
    ///    into (RULES.md §5, §7).
    ///
    /// Syntax colour is applied to the *storage* here rather than to a card's private copy, which is
    /// what lets it stay on while the writer types. It is still colour and nothing else: the spans come
    /// from `CodeHighlighting`, which never inserts, removes, or reorders a character.
    private static func styleCodeSource(in storage: NSTextStorage, doc: MarkupDocument,
                                        secondaryColor: UIColor,
                                        tokens: [CodeHighlighting.Token: UIColor] = [:],
                                        full: NSRange = NSRange(location: 0, length: 0),
                                        drawnAsCards: Set<ClosedRange<Int>> = []) {
        let text = storage.string
        guard text.contains(CodeBlock.fence) else { return }   // answered cheaply, as tables are
        let font = CodeCardLayout.font()

        for block in CodeBlock.blocks(in: text) where !drawnAsCards.contains(block.lineRange) {
            guard block.lineRange.lowerBound < doc.lines.count,
                  block.lineRange.upperBound < doc.lines.count else { continue }
            let opening = doc.lines[block.lineRange.lowerBound]
            let closing = doc.lines[block.lineRange.upperBound]
            let range = NSRange(location: opening.sourceRange.location,
                                length: closing.sourceRange.location + closing.sourceRange.length
                                    - opening.sourceRange.location)
            guard range.length > 0 else { continue }

            storage.addAttribute(.astCodeBlock, value: NSValue(range: range), range: range)
            storage.addAttribute(.font, value: font, range: range)

            // A block with nothing in it yet keeps its fences on screen. Hiding both would leave the
            // writer looking at an empty strip with no way to tell what it is or where to type.
            guard block.lineRange.upperBound > block.lineRange.lowerBound + 1 else {
                for line in [opening, closing] where line.sourceRange.length > 0 {
                    storage.addAttribute(.foregroundColor, value: secondaryColor, range: line.sourceRange)
                }
                continue
            }

            colourCode(in: storage, block: block, doc: doc, tokens: tokens)
            insetCode(in: storage, block: block, doc: doc)
            // The two fences carry everything the card draws around its code, so that a block occupies
            // the same space whichever presentation is on screen: the air above the block, the header
            // strip, and the card's own top padding all live on the opening fence; the bottom padding
            // and the air below it on the closing one. Without the margins here, moving focus to the
            // title flipped the block to its card and moved it *down* the page by `blockMargin` — the
            // one presentation had a margin above it and the other did not (fixed 2026-08-28).
            hide(opening, in: storage,
                 height: CodeCardLayout.Metrics.blockMargin
                     + CodeCardLayout.Metrics.headerHeight
                     + CodeCardLayout.Metrics.cardInsetV,
                 full: full)
            hide(closing, in: storage,
                 height: CodeCardLayout.Metrics.cardInsetV + CodeCardLayout.Metrics.blockMargin,
                 full: full)
        }
    }

    /// The syntax spans, mapped from the block's own code offsets into the note's.
    ///
    /// `block.code` is the code lines joined by "\n", and those lines are consecutive in `body` with the
    /// same separator, so offset *i* of the code is offset `codeStart + i` of the source. Every span is
    /// bounds-checked against the code region anyway — colour must never be able to reach past it.
    private static func colourCode(in storage: NSTextStorage, block: CodeBlock,
                                   doc: MarkupDocument, tokens: [CodeHighlighting.Token: UIColor]) {
        guard let language = CodeHighlighting.language(named: block.language), !tokens.isEmpty else { return }
        let firstCode = doc.lines[block.lineRange.lowerBound + 1]
        let lastCode = doc.lines[block.lineRange.upperBound - 1]
        let start = firstCode.sourceRange.location
        let end = lastCode.sourceRange.location + lastCode.sourceRange.length
        guard end > start else { return }

        for span in CodeHighlighting.spans(in: block.code, language: language) {
            guard let colour = tokens[span.token] else { continue }
            let mapped = NSRange(location: start + span.range.location, length: span.range.length)
            guard mapped.location >= start, NSMaxRange(mapped) <= end else { continue }
            storage.addAttribute(.foregroundColor, value: colour, range: mapped)
        }
    }

    /// Sits the code where the card draws it.
    ///
    /// Measured rather than assumed, and it is the difference between "the block stays put" and "the
    /// block jumps": a card draws its code `cardInsetH` in from its own edge, while the text view lays
    /// the same characters out against the writing margin. Without this every line of a block slid 14
    /// points left the moment the caret arrived — which is precisely the visible break this whole
    /// presentation exists to remove.
    private static func insetCode(in storage: NSTextStorage, block: CodeBlock, doc: MarkupDocument) {
        let inset = CodeCardLayout.Metrics.cardInsetH
        for index in (block.lineRange.lowerBound + 1)...(block.lineRange.upperBound - 1)
        where index < doc.lines.count {
            let line = doc.lines[index]
            let lineEnd = line.sourceRange.location + line.sourceRange.length
            let range = NSRange(location: line.sourceRange.location,
                                length: line.sourceRange.length
                                    + (lineEnd < storage.length ? 1 : 0))
            guard range.length > 0 else { continue }
            let existing = storage.attribute(.paragraphStyle, at: range.location,
                                             effectiveRange: nil) as? NSParagraphStyle
            let paragraph = (existing?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = inset
            paragraph.headIndent = inset
            // A negative tail indent is measured from the trailing margin, so a long line wraps inside
            // the card rather than running under its right edge.
            paragraph.tailIndent = -inset
            storage.addAttribute(.paragraphStyle, value: paragraph, range: range)
        }
    }

    /// Takes one line's glyphs away and pins the height of the strip they leave behind.
    ///
    /// The hidden attribute goes on the line's characters and **not** its newline — a hidden character
    /// is drawn as a zero-advancement control glyph, and doing that to a newline overrides the line
    /// break it exists to perform, collapsing the following line into this one's fragment. The
    /// paragraph style does include the newline, because a paragraph's height is set by the whole
    /// paragraph and the newline is its last character. (Both lessons are the table rule row's,
    /// learned the hard way on 2026-08-23.)
    private static func hide(_ line: MarkupDocument.Line, in storage: NSTextStorage,
                             height: CGFloat, full: NSRange) {
        guard line.sourceRange.length > 0 else { return }
        storage.addAttribute(.astHiddenMarker, value: true, range: line.sourceRange)

        let lineEnd = line.sourceRange.location + line.sourceRange.length
        let paragraphRange = NSRange(location: line.sourceRange.location,
                                     length: line.sourceRange.length
                                         + (lineEnd < full.length ? 1 : 0))
        storage.addAttribute(.paragraphStyle,
                             value: collapsing(to: height, leading: leading(in: storage, at: line)),
                             range: paragraphRange)
    }

    /// How much taller than its clamp a line on `line` will actually be laid out.
    ///
    /// `maximumLineHeight` clamps a line's **ascent and descent** and nothing else: TextKit adds the
    /// font's leading on top of the clamp, so a paragraph asked for one point comes back one point
    /// plus the leading. Measured on 2026-08-28 — the body face carries 1.71pt of it and a
    /// monospaced face carries none, which is why only the *reading* presentation ever drifted: a
    /// block being edited is set in the code face, where the arithmetic happened to be exact.
    ///
    /// Read from the storage rather than assumed, because the face on a line is whatever the passes
    /// above this one put there, and it changes with Dynamic Type.
    private static func leading(in storage: NSTextStorage, at line: MarkupDocument.Line) -> CGFloat {
        let index = line.sourceRange.location
        guard index < storage.length else { return 0 }
        return (storage.attribute(.font, at: index, effectiveRange: nil) as? UIFont)?.leading ?? 0
    }

    /// A paragraph style that makes its line occupy exactly `height` points, leading included.
    private static func collapsing(to height: CGFloat, leading: CGFloat) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 0
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        // Never zero: zero means "no clamp at all", and the line would spring back to its full height.
        let clamp = max(1, height - leading)
        paragraph.minimumLineHeight = clamp
        paragraph.maximumLineHeight = clamp
        return paragraph
    }

    /// Reading: a block's lines give up their glyphs and keep only their height.
    ///
    /// The words stay in `body`, character for character (RULES.md §5) — they are simply not what is
    /// drawn. Every line of the block is hidden at the glyph layer and the block is squeezed down to one
    /// tall, empty line fragment, into which `TableCardView` is positioned. That is the whole trick, and
    /// it is deliberately the *only* trick: the previous attempt re-spaced the source in place — pipes
    /// laid out as invisible tab stops, the delimiter row painted over with a hairline — and it kept
    /// leaking, because what was on screen was still the source with pieces of it hidden. Stray closing
    /// pipes, a grey band where the delimiter had been, columns aligned by spacing rather than geometry.
    /// A reader should never have to know that a table is stored as `| Day | Date |`.
    ///
    /// The height lands on the block's first line, and the rest collapse to a point each, because
    /// TextKit clamps line height per paragraph and each source line is its own paragraph. What the
    /// clamp does **not** cover is the font's leading, which is added on top of it — so the reserved
    /// region used to run about 1.7pt per line taller than the card going into it, an error that grew
    /// with the block and pushed the card down the page (fixed 2026-08-28, see `collapsing(to:leading:)`).
    /// Shared by tables and code blocks: both are read as a real view drawn over the space their
    /// source reserved, and neither asks the reader to decode how the note stores it.
    private static func reserveCards(in storage: NSTextStorage, doc: MarkupDocument,
                                     heights: [ClosedRange<Int>: CGFloat], full: NSRange) {
        for (lineRange, height) in heights {
            // Only the lines that can actually carry a paragraph style take part. A line with neither
            // characters nor a newline of its own cannot be clamped, and counting one into the
            // arithmetic below would leave the region taller than the card by whatever it laid out as.
            let lines: [(line: MarkupDocument.Line, styled: NSRange, leading: CGFloat)] =
                lineRange.compactMap { index in
                    guard index < doc.lines.count else { return nil }
                    let line = doc.lines[index]
                    let lineEnd = line.sourceRange.location + line.sourceRange.length
                    let styled = NSRange(location: line.sourceRange.location,
                                         length: line.sourceRange.length
                                             + (lineEnd < full.length ? 1 : 0))
                    guard styled.length > 0 else { return nil }
                    return (line, styled, leading(in: storage, at: line))
                }
            guard let head = lines.first else { continue }

            // Every line occupies its clamp *plus* its font's leading (see `leading(in:at:)`). The tail
            // collapses to a point each and the head takes what is left, so the block's lines total
            // exactly the height the card needs — at four lines and at four hundred.
            let collapsed: CGFloat = 1
            let tail = lines.dropFirst().reduce(CGFloat(0)) { $0 + collapsed + $1.leading }
            let first = max(1, height - tail - head.leading)

            for (offset, entry) in lines.enumerated() {
                let occupies = (offset == 0 ? first : collapsed) + entry.leading
                storage.addAttribute(.paragraphStyle,
                                     value: collapsing(to: occupies, leading: entry.leading),
                                     range: entry.styled)
                if entry.line.sourceRange.length > 0 {
                    storage.addAttribute(.astHiddenMarker, value: true, range: entry.line.sourceRange)
                }
            }
        }
    }

    /// Editing: the same lines, shown as what they are.
    ///
    /// A table being edited is text being edited, and pretending otherwise is how the caret ends up
    /// somewhere the writer cannot see it. The pipes recede to the colour of punctuation and the block
    /// keeps a quiet container so it still reads as one table, but nothing is hidden and nothing moves.
    /// This is the "edit as text" presentation (RULES.md §7, amended 2026-08-21), and the note returns to
    /// its cards the moment the keyboard goes away.
    ///
    /// - Parameter drawnAsCards: the tables a card is being drawn over — see `styleCodeSource`.
    private static func styleTableSource(in storage: NSTextStorage, doc: MarkupDocument,
                                         secondaryColor: UIColor,
                                         drawnAsCards: Set<ClosedRange<Int>> = []) {
        let text = storage.string
        guard text.contains("|") else { return }   // the overwhelmingly common case, answered cheaply

        let ns = text as NSString
        for table in TableBlock.tables(in: text) where !drawnAsCards.contains(table.lineRange) {
            // *One* range across the whole block, newlines included. Marking each line separately left
            // the newlines between them unmarked, so the drawing pass saw one run per line and stacked a
            // rounded rectangle behind each — the banded staircase that made a table look like
            // highlighted text rather than a block on the page.
            guard table.lineRange.lowerBound < doc.lines.count else { continue }
            let last = doc.lines[min(table.lineRange.upperBound, doc.lines.count - 1)]
            let start = doc.lines[table.lineRange.lowerBound].sourceRange.location
            let block = NSRange(location: start,
                                length: last.sourceRange.location + last.sourceRange.length - start)
            guard block.length > 0 else { continue }
            storage.addAttribute(.astTableBlock, value: NSValue(range: block), range: block)

            // The rule is the row directly under the header, identified by *position* rather than by
            // re-reading each line: asking "does this look like a rule?" of every row would hide a
            // data row that happens to hold only dashes.
            let ruleLine = table.hasHeaderRule ? table.lineRange.lowerBound + 1 : nil
            for lineIndex in table.lineRange where lineIndex < doc.lines.count {
                let line = doc.lines[lineIndex]
                guard line.sourceRange.length > 0 else { continue }

                // The delimiter row goes, here as on every other surface. It is how the note records
                // which row is the header — nobody typed it to be read, and it says nothing about the
                // table's contents. It stays in `body` untouched; it simply is not drawn.
                //
                // This is **not** the re-spacing that was tried and rejected on 2026-08-21: no pipe is
                // moved, no hairline is painted, and no line is made to look like something it is not.
                // One line stops being drawn and every other line stays exactly as it was typed.
                if lineIndex == ruleLine {
                    // The line's characters, and **not** its newline. A hidden character is drawn as a
                    // zero-advancement control glyph, and doing that to a newline overrides the line
                    // break it exists to perform: the first data row then had no line of its own, fell
                    // into the delimiter's collapsed fragment, and was squashed to three points of
                    // nothing — the top row of every table with a header rule, gone while editing it.
                    let hidden = line.sourceRange
                    storage.addAttribute(.astHiddenMarker, value: true, range: hidden)
                    // Its glyphs are gone, so its line must not keep the height they would have had.
                    // The style goes on the newline too, because a paragraph's height is set by the
                    // whole paragraph and the newline is the last character of this one.
                    let lineEnd = line.sourceRange.location + line.sourceRange.length
                    let paragraphRange = NSRange(location: line.sourceRange.location,
                                                 length: line.sourceRange.length
                                                     + (lineEnd < storage.length ? 1 : 0))
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.lineSpacing = 0
                    paragraph.paragraphSpacing = 0
                    paragraph.paragraphSpacingBefore = 0
                    paragraph.minimumLineHeight = 1
                    paragraph.maximumLineHeight = 1
                    storage.addAttribute(.paragraphStyle, value: paragraph, range: paragraphRange)
                    continue
                }

                var index = line.sourceRange.location
                let end = line.sourceRange.location + line.sourceRange.length
                while index < end {
                    if ns.character(at: index) == unichar(124) {   // "|"
                        storage.addAttribute(.foregroundColor, value: secondaryColor,
                                             range: NSRange(location: index, length: 1))
                    }
                    index += 1
                }
            }
        }
    }
}

/// A layout manager that hides the glyphs of source markers and draws the visible list markers.
final class StructuredLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    /// Accent used to fill a checked checkbox; set by the view so it matches the design system.
    var accentColor: UIColor = .label

    /// The colour of a gutter marker — bullet, number, and the outline of an *unticked* box. Set by
    /// the view to the design system's secondary text token.
    ///
    /// One semantic colour, not three custom alphas (2026-08-20). The number used to be drawn at 70%
    /// of the body colour and the empty box at 55%, which is fainter than any text in the app: an
    /// unticked box landed at 3.75:1 on Light canvas, below the 4.5:1 the design system requires of
    /// every other glyph. That faintness is what made the markers *read* as too small — measurement
    /// showed the type beside them is the same 17pt body as the prose, so the fix is contrast, never
    /// geometry. Secondary takes the box to 6.3:1 Light / 8.5:1 Dark; the bullet comes *down* from
    /// full body colour to join them, because a marker is not the sentence.
    var markerColor: UIColor = .secondaryLabel

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    // MARK: Hide marker glyphs (zero advancement, not drawn)

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes: UnsafePointer<Int>,
                       font: UIFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard let storage = textStorage else {
            layoutManager.setGlyphs(glyphs, properties: props, characterIndexes: characterIndexes,
                                    font: font, forGlyphRange: glyphRange)
            return glyphRange.length
        }

        var newProps = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
        var changed = false
        for i in 0..<glyphRange.length {
            let charIndex = characterIndexes[i]
            if charIndex < storage.length,
               storage.attribute(.astHiddenMarker, at: charIndex, effectiveRange: nil) != nil {
                newProps[i] = .controlCharacter
                changed = true
            }
        }
        guard changed else {
            layoutManager.setGlyphs(glyphs, properties: props, characterIndexes: characterIndexes,
                                    font: font, forGlyphRange: glyphRange)
            return glyphRange.length
        }
        newProps.withUnsafeBufferPointer { buffer in
            layoutManager.setGlyphs(glyphs, properties: buffer.baseAddress!, characterIndexes: characterIndexes,
                                    font: font, forGlyphRange: glyphRange)
        }
        return glyphRange.length
    }

    /// Marker glyphs are hidden by giving them *zero advancement*, not by nulling them.
    ///
    /// The distinction is the whole reason an empty list item is visible. A null glyph is ignored
    /// during layout, so a line holding nothing but its marker — exactly what Return produces, and
    /// what the Style menu produces on a blank line — laid out to no height at all: the caret stayed
    /// on the line above, no bullet/number/box appeared, and the marker drew itself over the item
    /// above. A zero-advancement control glyph still takes part in layout, so the line keeps its
    /// full height and its own fragment while the marker itself stays invisible.
    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldUse action: NSLayoutManager.ControlCharacterAction,
                       forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        guard let storage = textStorage, charIndex < storage.length else { return action }
        if storage.attribute(.astHiddenMarker, at: charIndex, effectiveRange: nil) != nil {
            return .zeroAdvancement
        }
        return action
    }

    // MARK: Draw the container behind a table's source

    /// The quiet container behind a table block while its source is on screen. Drawing, not layout:
    /// nothing here changes where a glyph sits or which character the caret is on. A table being read
    /// has no container of its own to draw — `TableCardView` is a real view, and draws itself.
    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage, let container = textContainers.first else { return }
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)

        // One container per table, spanning the writing width rather than the width of whichever line
        // happens to be longest — a table is a block on the page, not a run of highlighted text.
        storage.enumerateAttribute(.astTableBlock, in: charRange) { value, range, _ in
            guard value != nil else { return }
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let bounds = boundingRect(forGlyphRange: glyphs, in: container)
            let rect = CGRect(x: origin.x - 10,
                              y: origin.y + bounds.minY - 6,
                              width: container.size.width + 20,
                              height: bounds.height + 12)
            tableFill.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()
        }

        // The same rectangle a `CodeBlockView` occupies, so a block does not change width when the
        // caret arrives — the card spans the writing width exactly, and so does this.
        storage.enumerateAttribute(.astCodeBlock, in: charRange) { value, range, _ in
            guard value != nil else { return }
            let glyphs = glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let bounds = boundingRect(forGlyphRange: glyphs, in: container)
            let rect = CGRect(x: origin.x,
                              y: origin.y + bounds.minY,
                              width: container.size.width,
                              height: bounds.height)
            codeFill.setFill()
            UIBezierPath(roundedRect: rect,
                         cornerRadius: CodeCardLayout.Metrics.corner).fill()
        }
    }

    /// The container's fill — set by the view from the design system, like the marker colours.
    var tableFill: UIColor = UIColor.label.withAlphaComponent(0.04)
    /// The ground behind a code block's source while it is being edited.
    var codeFill: UIColor = UIColor.label.withAlphaComponent(0.05)

    // MARK: Draw visible list markers in the gutter

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard let storage = textStorage else { return }
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let doc = MarkupDocument(storage.string)

        for line in doc.lines where StructuredTextStyle.isList(line.kind) {
            guard NSIntersectionRange(line.sourceRange, charRange).length > 0
                    || NSLocationInRange(line.sourceRange.location, charRange)
                    || (line.sourceRange.length == 0 && line.sourceRange.location == charRange.location)
            else { continue }

            // Anchor to the line's own first character. Marker glyphs are zero-advancement control
            // glyphs rather than null ones, so they still belong to this line's fragment — which is
            // what lets an item that holds *only* a marker (the moment after Return) draw its marker
            // on its own line instead of over the item above it.
            let anchorChar = line.sourceRange.location
            let glyphIndex = glyphIndexForCharacter(at: anchorChar)
            let fragment = lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            // Align to the text *baseline*, not to the middle of the fragment: the fragment's height
            // carries this paragraph's line spacing below the text, so a centered marker rides that
            // low by half the leading. `location(forGlyphAt:)` is relative to the fragment origin and
            // its y is the baseline, so this stays correct at every Dynamic Type size.
            let baselineY = origin.y + fragment.minY + location(forGlyphAt: glyphIndex).y
            drawMarker(for: line.kind, x: origin.x, baselineY: baselineY)
        }
    }

    private func drawMarker(for kind: BlockKind, x: CGFloat, baselineY: CGFloat) {
        // The *line's own* font, from the one definition the text is set in, so the bullet, the number
        // and the checkbox scale with the item beside them at every Dynamic Type size rather than
        // tracking a second, separately-declared idea of body size.
        let font = StructuredTextStyle.font(for: kind)
        switch kind {
        case .bullet:
            drawText("•", font: font, color: markerColor, x: x, baselineY: baselineY)
        case .numbered(let n):
            drawText("\(n).", font: font, color: markerColor, x: x, baselineY: baselineY)
        case .checklist(let checked):
            drawCheckbox(checked: checked, x: x, baselineY: baselineY, font: font)
        case .paragraph, .heading, .subheading:
            break
        }
    }

    private func drawText(_ string: String, font: UIFont, color: UIColor, x: CGFloat, baselineY: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        // `draw(at:)` takes the text's top-left, so back off the ascender to land on the baseline.
        let point = CGPoint(x: x + 6, y: baselineY - font.ascender)
        (string as NSString).draw(at: point, withAttributes: attributes)
    }

    private func drawCheckbox(checked: Bool, x: CGFloat, baselineY: CGFloat, font: UIFont) {
        let name = checked ? "checkmark.square.fill" : "square"
        let config = UIImage.SymbolConfiguration(font: font)
        guard let image = UIImage(systemName: name, withConfiguration: config)?
            .withTintColor(checked ? accentColor : markerColor, renderingMode: .alwaysOriginal)
        else { return }
        // Centred on the cap height rather than the fragment: a box optically sits with the letters
        // beside it, not with the leading underneath them.
        let centerY = baselineY - font.capHeight / 2
        image.draw(at: CGPoint(x: x + 2, y: centerY - image.size.height / 2))
    }
}
