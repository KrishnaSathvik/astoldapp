import UIKit
import SwiftUI

/// Keeps the note's table cards in step with its text.
///
/// The text view is the only scroll view on the screen (`NotePageView`), so a card added as its subview
/// travels with the words for free — it is positioned once, in content coordinates, and every scroll,
/// rubber-band and keyboard move carries it along without a single frame of lag.
///
/// One card per table, re-used across edits so a keystroke three paragraphs away does not rebuild the
/// grid. Cards exist only while the note is being **read**: the moment the body takes the keyboard they
/// go, and the canonical pipe source comes back for the person who is editing it (RULES.md §7, amended
/// 2026-08-21).
@MainActor
final class TableCardPresenter {

    private var cards: [ClosedRange<Int>: TableCardView] = [:]
    /// What the cards were built from, so they can be repositioned without being planned again.
    private var plans: [(table: TableBlock, layout: TableCardLayout.Layout)] = []

    /// The tables that are currently drawn as cards, and the height each one's lines must be squeezed
    /// to. Returns nothing while the note is being edited, or before the page has a width.
    func plan(for tv: UITextView, showsCards: Bool) -> [ClosedRange<Int>: CGFloat] {
        let width = tv.textContainer.size.width - tv.textContainer.lineFragmentPadding * 2
        plans = (showsCards && width > 0)
            ? TableCardLayout.layouts(in: tv.text, availableWidth: width)
            : []
        return plans.reduce(into: [:]) { heights, plan in
            heights[plan.table.lineRange] = plan.layout.reservedHeight
        }
    }

    /// Creates, updates and retires the card views for the current plan. Call after the styler has run.
    func sync(in tv: UITextView, palette: TableCardView.Palette) {
        let wanted = Set(plans.map(\.table.lineRange))
        for (range, card) in cards where !wanted.contains(range) {
            card.removeFromSuperview()
            cards[range] = nil
        }
        for plan in plans {
            if let card = cards[plan.table.lineRange] {
                card.update(table: plan.table, layout: plan.layout, palette: palette)
            } else {
                let card = TableCardView(table: plan.table, layout: plan.layout, palette: palette)
                cards[plan.table.lineRange] = card
                tv.addSubview(card)
            }
        }
        position(in: tv)
    }

    /// Puts every card over the space its lines reserved.
    ///
    /// Measured, never assumed: the card sits centred in whatever the line fragments actually came out
    /// as, so the point of rounding TextKit adds to a clamped line height costs nothing. Cheap enough to
    /// run from `layoutSubviews`, which is where the header's height — and so every glyph's y — settles.
    func position(in tv: UITextView) {
        guard !cards.isEmpty else { return }
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        let doc = MarkupDocument(tv.text)
        for plan in plans {
            guard let card = cards[plan.table.lineRange],
                  let reserved = blockRect(plan.table.lineRange, in: tv, doc: doc) else { continue }
            let size = plan.layout.size
            // Fragments are reported in text-container space; the card lives in the text view's, and
            // the difference is the inset the page reserves for the date and title above the first line.
            let inset = tv.textContainerInset
            card.frame = CGRect(x: reserved.minX + inset.left,
                                y: reserved.midY + inset.top - size.height / 2,
                                width: size.width,
                                height: size.height)
        }
    }

    /// The table whose **preview** card is under `point`, if any.
    ///
    /// Only a preview answers. A card showing the whole table has nothing more to show, so a tap on it
    /// is a tap on the note — it places the caret, exactly as a tap on any other words does, and the
    /// table becomes editable text. A preview card is holding rows back and says so ("View Table"), so
    /// its tap opens the reader.
    func previewTable(at point: CGPoint, in tv: UITextView) -> TableBlock? {
        for plan in plans where plan.layout.isPreview {
            guard let card = cards[plan.table.lineRange] else { continue }
            if card.frame.insetBy(dx: -4, dy: -4).contains(point) { return plan.table }
        }
        return nil
    }

    /// The union of the line fragments belonging to `lineRange`, in text-container coordinates.
    private func blockRect(_ lineRange: ClosedRange<Int>, in tv: UITextView,
                           doc: MarkupDocument) -> CGRect? {
        guard lineRange.lowerBound < doc.lines.count else { return nil }
        let first = doc.lines[lineRange.lowerBound]
        let last = doc.lines[min(lineRange.upperBound, doc.lines.count - 1)]
        let end = last.sourceRange.location + last.sourceRange.length
        let characters = NSRange(location: first.sourceRange.location,
                                 length: max(0, end - first.sourceRange.location))

        let manager = tv.layoutManager
        let glyphs = manager.glyphRange(forCharacterRange: characters, actualCharacterRange: nil)
        var rect = CGRect.null
        manager.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, _, _ in
            rect = rect.union(fragment)
        }
        return rect.isNull ? nil : rect
    }
}

extension TableCardView.Palette {
    /// The card in the app's own colours. Resolved from the semantic tokens rather than from anything
    /// fixed, so Light and Dark are one definition (RULES.md §4).
    @MainActor static var ds: TableCardView.Palette {
        TableCardView.Palette(
            surface: UIColor(Color.ds.surface),
            text: UIColor(Color.ds.textPrimary),
            secondaryText: UIColor(Color.ds.textSecondary),
            separator: UIColor(Color.ds.textTertiary).withAlphaComponent(0.35),
            headerFill: UIColor(Color.ds.textPrimary).withAlphaComponent(0.045),
            accent: UIColor(Color.ds.accent)
        )
    }
}
