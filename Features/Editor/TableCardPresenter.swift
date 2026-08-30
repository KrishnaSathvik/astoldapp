import UIKit
import SwiftUI

/// Keeps the note's table cards in step with its text.
///
/// The text view is the only scroll view on the screen (`NotePageView`), so a card added as its subview
/// travels with the words for free — it is positioned once, in content coordinates, and every scroll,
/// rubber-band and keyboard move carries it along without a single frame of lag.
///
/// One card per table, re-used across edits so a keystroke three paragraphs away does not rebuild the
/// grid. A table shows its canonical pipe source only while **the caret is inside that table** — every
/// other table on the page stays a card, keyboard up or down (RULES.md §7, amended 2026-08-21 and
/// again 2026-08-23).
@MainActor
final class TableCardPresenter {

    private var cards: [ClosedRange<Int>: TableCardView] = [:]
    /// What the cards were built from, so they can be repositioned without being planned again.
    private var plans: [(table: TableBlock, layout: TableCardLayout.Layout)] = []
    /// Measured layouts, keyed by everything that can change one. A table's column widths come from
    /// measuring every cell, and `restyle` runs on every keystroke — a note with a dozen tables would
    /// otherwise re-measure all of them on every character typed next to them.
    private var measured: [Key: TableCardLayout.Layout] = [:]

    private struct Key: Hashable {
        let rows: [[String]]
        let hasHeaderRule: Bool
        let width: CGFloat
        /// Dynamic Type changes the font, and the font changes every measurement.
        let textSize: CGFloat
    }

    /// The tables currently drawn as cards, and the height each one's lines must be squeezed to.
    ///
    /// - Parameter sourceLines: the lines that must show their **source** — the ones the caret is in.
    ///   A table overlapping them de-renders; every other table stays a card. `nil` means nothing is
    ///   being edited and every table renders.
    ///
    /// This replaced an all-or-nothing `showsCards` on 2026-08-23. Under that rule, tapping anywhere
    /// to type turned **every** table in the note back into pipe rows at once — a note of thirteen
    /// tables became thirteen blocks of raw syntax because someone wanted to add one sentence.
    func plan(for tv: UITextView, sourceLines: ClosedRange<Int>?) -> [ClosedRange<Int>: CGFloat] {
        let width = tv.textContainer.size.width - tv.textContainer.lineFragmentPadding * 2
        guard width > 0 else { plans = []; return [:] }

        let textSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        if measured.count > 64 { measured.removeAll(keepingCapacity: true) }

        // Every table, always. Amended 2026-08-24 (Item 4): a table no longer gives up its grid to be
        // edited, because it is now edited *as a grid* — `TableCardView` takes the cell edit and hands
        // back a `TextEdit` against `body`. `sourceLines` is therefore no longer consulted here; the
        // pipes and the header rule are storage, and storage is never drawn (RULES.md §7).
        _ = sourceLines
        plans = TableBlock.tables(in: tv.text).compactMap { table in
            guard let layout = layout(for: table, width: width, textSize: textSize) else { return nil }
            return (table, layout)
        }
        return plans.reduce(into: [:]) { heights, plan in
            heights[plan.table.lineRange] = plan.layout.reservedHeight
        }
    }

    private func layout(for table: TableBlock, width: CGFloat,
                        textSize: CGFloat) -> TableCardLayout.Layout? {
        let key = Key(rows: table.rows, hasHeaderRule: table.hasHeaderRule,
                      width: width, textSize: textSize)
        if let hit = measured[key] { return hit }
        guard let layout = TableCardLayout.layout(for: table, availableWidth: width) else { return nil }
        measured[key] = layout
        return layout
    }

    /// Creates, updates and retires the card views for the current plan. Call after the styler has run.
    /// - Parameter commit: turns one cell edit into a change to `body`. The card never writes to the
    ///   note itself — it reports which cell changed and to what, and the editor makes that a normal,
    ///   undoable text edit like every other structural operation (RULES.md §4).
    func sync(in tv: UITextView, palette: TableCardView.Palette,
              commit: ((TableBlock, TableBlock.CellPosition, String) -> Void)? = nil) {
        let wanted = Set(plans.map(\.table.lineRange))
        for (range, card) in cards where !wanted.contains(range) {
            // Retiring a card MUST commit what is open in it (2026-08-27). This passed `commit: false`,
            // which made ordinary card churn — the note re-laying out around an edit — a silent way to
            // throw away text somebody had just typed.
            card.endEditing()
            card.removeFromSuperview()
            cards[range] = nil
        }
        for plan in plans {
            let card: TableCardView
            if let existing = cards[plan.table.lineRange] {
                existing.update(table: plan.table, layout: plan.layout, palette: palette)
                card = existing
            } else {
                card = TableCardView(table: plan.table, layout: plan.layout, palette: palette)
                cards[plan.table.lineRange] = card
                tv.addSubview(card)
            }
            // Re-bound every sync: the closure captures the table as it is *now*, and a cell edit is
            // computed against the rows the writer is actually looking at.
            let table = plan.table
            card.onCommit = { [weak card] position, text in
                commit?(table, position, text)
                _ = card
            }
        }
        position(in: tv)
    }

    /// Whether a card on this page currently owns the keyboard for one of its cells.
    var isEditingACell: Bool { cards.values.contains { $0.isEditingACell } }

    /// Commits and closes any open cell on this page. **The** flush — every path that needs the note
    /// to be whole before it is read, written, or torn down calls this one, rather than each inventing
    /// its own idea of what an open cell means.
    ///
    /// Named for the commit rather than the closing (2026-08-27): it was `endCellEditing`, which read
    /// like teardown and was called from exactly one place — Share — so Share was the only exit in the
    /// app that did not lose a cell edit. Safe to call when nothing is open, and safe to call twice.
    func commitActiveCellEdits() {
        for card in cards.values { card.endEditing() }
    }

    /// Puts every card over the space its lines reserved.
    ///
    /// Measured, never assumed, and anchored to the **top** of what the line fragments actually came
    /// out as. It used to sit centred, which shared any error in the reservation evenly between the
    /// card's two sides and so turned half of it into blank page above the card — the same defect
    /// `CodeCardPresenter` had, from the same line of arithmetic (fixed 2026-08-28). Cheap enough to
    /// run from `layoutSubviews`, which is where the header's height — and so every glyph's y — settles.
    func position(in tv: UITextView) {
        guard !cards.isEmpty else { return }
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        let text = tv.text as NSString
        for plan in plans {
            guard let card = cards[plan.table.lineRange],
                  let reserved = blockRect(plan.table.lineRange, in: tv, text: text) else { continue }
            let size = plan.layout.size
            // Fragments are reported in text-container space; the card lives in the text view's, and
            // the difference is the inset the page reserves for the date and title above the first line.
            let inset = tv.textContainerInset
            card.frame = CGRect(x: reserved.minX + inset.left,
                                y: reserved.minY + inset.top + TableCardLayout.Metrics.blockMargin,
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
                           text: NSString) -> CGRect? {
        guard let characters = StructuredText.characterRange(ofLines: lineRange, in: text) else {
            return nil
        }
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
