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
    static func apply(to storage: NSTextStorage, textColor: UIColor,
                      secondaryColor: UIColor = .secondaryLabel,
                      availableWidth: CGFloat = 0,
                      tableCards: [ClosedRange<Int>: CGFloat] = [:]) {
        let text = storage.string
        let doc = MarkupDocument(text)
        let full = NSRange(location: 0, length: (text as NSString).length)

        storage.beginEditing()
        storage.removeAttribute(.astHiddenMarker, range: full)
        storage.removeAttribute(.astTableBlock, range: full)

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
        }

        if tableCards.isEmpty {
            styleTableSource(in: storage, doc: doc, secondaryColor: secondaryColor)
        } else {
            reserveTableCards(in: storage, doc: doc, heights: tableCards, full: full)
        }
        storage.endEditing()
    }

    /// Reading: the table's lines give up their glyphs and keep only their height.
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
    /// TextKit clamps line height per paragraph and each source line is its own paragraph. The card is
    /// then positioned against the block's *measured* fragments rather than against this arithmetic, so
    /// a point of rounding either way costs nothing.
    private static func reserveTableCards(in storage: NSTextStorage, doc: MarkupDocument,
                                          heights: [ClosedRange<Int>: CGFloat], full: NSRange) {
        for (lineRange, height) in heights {
            let indices = lineRange.filter { $0 < doc.lines.count }
            guard !indices.isEmpty else { continue }
            let collapsed: CGFloat = 1
            let first = max(1, height - collapsed * CGFloat(indices.count - 1))

            for (offset, lineIndex) in indices.enumerated() {
                let line = doc.lines[lineIndex]
                let lineEnd = line.sourceRange.location + line.sourceRange.length
                let styled = NSRange(location: line.sourceRange.location,
                                     length: line.sourceRange.length + (lineEnd < full.length ? 1 : 0))
                guard styled.length > 0 else { continue }

                let paragraph = NSMutableParagraphStyle()
                paragraph.lineSpacing = 0
                paragraph.paragraphSpacing = 0
                paragraph.paragraphSpacingBefore = 0
                let lineHeight = offset == 0 ? first : collapsed
                paragraph.minimumLineHeight = lineHeight
                paragraph.maximumLineHeight = lineHeight
                storage.addAttribute(.paragraphStyle, value: paragraph, range: styled)
                if line.sourceRange.length > 0 {
                    storage.addAttribute(.astHiddenMarker, value: true, range: line.sourceRange)
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
    private static func styleTableSource(in storage: NSTextStorage, doc: MarkupDocument,
                                         secondaryColor: UIColor) {
        let text = storage.string
        guard text.contains("|") else { return }   // the overwhelmingly common case, answered cheaply

        let ns = text as NSString
        for table in TableBlock.tables(in: text) {
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

            for lineIndex in table.lineRange where lineIndex < doc.lines.count {
                let line = doc.lines[lineIndex]
                guard line.sourceRange.length > 0 else { continue }

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

    }

    /// The container's fill — set by the view from the design system, like the marker colours.
    var tableFill: UIColor = UIColor.label.withAlphaComponent(0.04)

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
