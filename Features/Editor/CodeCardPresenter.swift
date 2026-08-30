import UIKit
import SwiftUI

/// Keeps the note's code cards in step with its text.
///
/// The same arrangement `TableCardPresenter` uses, for the same reasons: the text view is the only
/// scroll view on the screen, so a card added as its subview travels with the words for free, and one
/// card per block is re-used across edits so a keystroke elsewhere does not rebuild it.
///
/// A block shows its canonical fenced source only while **the caret is inside that block** — the one
/// being edited, and no other. Every other code block on the page stays a card, keyboard up or down
/// (RULES.md §7). The caret still has to be somewhere the writer can see it; what changed on
/// 2026-08-23 is that this no longer costs every *other* block its rendering.
@MainActor
final class CodeCardPresenter {

    private var cards: [ClosedRange<Int>: CodeBlockView] = [:]
    private var plans: [(block: CodeBlock, layout: CodeCardLayout.Layout, mode: CodeBlockView.Mode)] = []
    /// Measured layouts, keyed by everything that can change one. Laying out a block means measuring
    /// its widest line, and `restyle` runs on every keystroke — without this, typing a sentence next
    /// to a dozen code blocks re-measures all of them on every character.
    private var measured: [Key: CodeCardLayout.Layout] = [:]

    private struct Key: Hashable {
        let code: String
        let language: String?
        let width: CGFloat
        /// Dynamic Type changes the font, and the font changes every measurement.
        let textSize: CGFloat
    }

    /// The blocks currently drawn as cards, and the height each one's lines must be squeezed to.
    ///
    /// - Parameter sourceLines: the lines that must show their **source** — the ones the caret is in.
    ///   A block overlapping them de-renders; every other block stays a card, keyboard up or down.
    ///   `nil` means nothing is being edited and everything renders.
    ///
    /// This replaced an all-or-nothing `showsCards` on 2026-08-23. Under that rule, tapping anywhere
    /// to type one sentence turned **every** block in the note back into raw source at once, which made
    /// a long note look broken for the sake of an edit happening somewhere else entirely.
    func plan(for tv: UITextView, sourceLines: ClosedRange<Int>?) -> [ClosedRange<Int>: CGFloat] {
        let width = tv.textContainer.size.width - tv.textContainer.lineFragmentPadding * 2
        guard width > 0 else { plans = []; return [:] }

        let textSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        if measured.count > 64 { measured.removeAll(keepingCapacity: true) }

        // Every block gets a view. The one the caret is in gets the *header* of one — its ground, its
        // language and its Copy Code — while the text view underneath draws the code the writer is
        // typing into (RULES.md §7, amended 2026-08-24). Only a block with no code yet is left showing
        // its fences, because a block with nothing in it and nothing on screen is a block nobody can
        // find their way into.
        plans = CodeBlock.blocks(in: tv.text).compactMap { block in
            guard let layout = layout(for: block, width: width, textSize: textSize) else { return nil }
            let editing = sourceLines?.overlaps(block.lineRange) == true
            if editing, block.codeLines.isEmpty { return nil }
            return (block, layout, editing ? .editing : .reading)
        }
        // Only a block drawn *whole* reserves the height of a card. An edited block's lines keep their
        // own heights, because they are the lines being edited.
        return plans.reduce(into: [:]) { heights, plan in
            guard plan.mode == .reading else { return }
            heights[plan.block.lineRange] = plan.layout.reservedHeight
        }
    }

    private func layout(for block: CodeBlock, width: CGFloat,
                        textSize: CGFloat) -> CodeCardLayout.Layout? {
        let key = Key(code: block.code, language: block.language, width: width, textSize: textSize)
        if let hit = measured[key] { return hit }
        guard let layout = CodeCardLayout.layout(for: block, availableWidth: width) else { return nil }
        measured[key] = layout
        return layout
    }

    /// Creates, updates and retires the card views for the current plan. Call after the styler has run.
    func sync(in tv: UITextView, palette: CodeBlockView.Palette) {
        let wanted = Set(plans.map(\.block.lineRange))
        for (range, card) in cards where !wanted.contains(range) {
            card.removeFromSuperview()
            cards[range] = nil
        }
        for plan in plans {
            if let card = cards[plan.block.lineRange] {
                card.update(block: plan.block, layout: plan.layout, palette: palette, mode: plan.mode)
            } else {
                let card = CodeBlockView(block: plan.block, layout: plan.layout,
                                         palette: palette, mode: plan.mode)
                cards[plan.block.lineRange] = card
                tv.addSubview(card)
            }
        }
        position(in: tv)
    }

    /// Puts every card over the space its lines reserved — measured, never assumed.
    ///
    /// Anchored to the **top** of that space, not centred in it. Centring shared any error in the
    /// reservation evenly between the card's two sides, so half of it became blank page above the
    /// card — and the error grew with the block, which is how a long block acquired a visible hole
    /// above it the moment focus moved to the title (fixed 2026-08-28). Anchoring makes the drawn
    /// block's top depend on the block's first line and nothing else.
    func position(in tv: UITextView) {
        guard !cards.isEmpty else { return }
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        let text = tv.text as NSString
        for plan in plans {
            guard let card = cards[plan.block.lineRange] else { continue }
            let inset = tv.textContainerInset

            if plan.mode == .editing {
                // The header sits over the opening fence line, whose glyphs are hidden and whose height
                // the styler holds at exactly this. Covering only that strip is what leaves the code
                // below it reachable: the card is a subview and would otherwise draw over the very
                // characters the writer came here to edit. The strip also carries the block's top
                // margin, which the header sits below — the same margin the card keeps while reading.
                let opening = plan.block.lineRange.lowerBound
                guard let strip = blockRect(opening...opening, in: tv, text: text) else { continue }
                card.frame = CGRect(x: strip.minX + inset.left,
                                    y: strip.minY + inset.top + CodeCardLayout.Metrics.blockMargin,
                                    width: plan.layout.size.width,
                                    height: CodeCardLayout.Metrics.headerHeight)
                continue
            }

            guard let reserved = blockRect(plan.block.lineRange, in: tv, text: text) else { continue }
            let size = plan.layout.size
            card.frame = CGRect(x: reserved.minX + inset.left,
                                y: reserved.minY + inset.top + CodeCardLayout.Metrics.blockMargin,
                                width: size.width,
                                height: size.height)
        }
    }

    /// The rendered card a horizontal drag beginning at `point` would scroll, if any.
    ///
    /// `point` is in the text view's coordinates. Returns nil when the touch is over no card, over a
    /// card that already fits, over one being edited, or over Copy — every case where the gesture must be
    /// left alone to mean what it has always meant (added 2026-08-25; widened from preformatted-only to
    /// every wide card the same day, so code keeps its own "never wrap" promise).
    func horizontallyScrollableCard(at point: CGPoint) -> CodeBlockView? {
        cards.values.first { card in
            card.frame.contains(point)
                && card.acceptsHorizontalPan(at: card.convert(point, from: card.superview))
        }
    }

    /// Whether a card claims the touch at `point` — which only **Copy Code** ever does.
    ///
    /// Everything else on a card is transparent, so a tap reaches the text underneath and puts the
    /// caret in the code, the same way a tap on a table card does.
    func handlesTouch(at point: CGPoint) -> Bool {
        cards.values.contains { card in
            card.claimsTouch(at: card.convert(point, from: card.superview))
        }
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
