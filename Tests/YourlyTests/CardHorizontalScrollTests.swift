import Testing
import Foundation
import UIKit
@testable import Yourly

// Making a wide diagram reachable with a finger, without making the card eat touches.
//
// The contradiction this resolves: a wide preformatted card correctly refuses to wrap, correctly
// measures wider than the page, correctly draws a scroll indicator — and could not be scrolled at all,
// because `CodeBlockView.hitTest` returns nil for everything but Copy. That transparency is deliberate
// and stays: it is what lets a tap pass through the card and put the caret in the source underneath,
// and owning the card's touches once left a block with **no way in** at all.
//
// So the drag is claimed at the text view, not by the card. The rule is narrow enough to state in one
// line: **a clearly horizontal drag, starting over a rendered card that is actually wider than its
// viewport, scrolls that card.** Everything else — taps, vertical drags, Copy, and any gesture over a
// card that fits — behaves exactly as it did before.
//
// Widened from preformatted-only to **every** wide card later the same day. The narrow version left a
// wide *code* card drawing a scroll indicator that no finger could move, which is not a smaller version
// of the promise in `RULES.md` §7 ("long lines scroll horizontally; they never wrap") — it is the
// promise advertised and not kept. A code card and a diagram card are the same card with a different
// label.
@MainActor
struct CardHorizontalScrollTests {

    private let wide = String(repeating: "─", count: 80)
    /// A line of real code that is simply too long for the page — no box-drawing characters, so this is
    /// unambiguously a code block and not a diagram that happens to be labelled.
    private let wideCode = "let result = "
        + String(repeating: "someValue + ", count: 20) + "0"


    private func card(_ lines: [String], language: String?,
                      mode: CodeBlockView.Mode = .reading) -> CodeBlockView {
        let block = CodeBlock(language: language, lineRange: 0...(lines.count + 1), codeLines: lines)
        let layout = CodeCardLayout.layout(for: block, availableWidth: 353)!
        let view = CodeBlockView(block: block, layout: layout, palette: .ds, mode: mode)
        view.frame = CGRect(origin: .zero, size: layout.size)
        view.layoutIfNeeded()
        return view
    }

    // MARK: Which cards offer to scroll at all

    @Test func aWidePreformattedCardScrollsHorizontally() {
        #expect(card([wide, wide], language: "text").scrollsHorizontally)
    }

    @Test func aCardThatFitsDoesNotOfferToScroll() {
        // "no gesture should activate for a card that fits within the viewport" — otherwise every
        // sideways twitch over a short diagram would fight the note's own scrolling for no reason.
        #expect(!card(["apps/", "└── web/"], language: "text").scrollsHorizontally)
    }

    @Test func aCardBeingEditedDoesNotOfferToScroll() {
        // Its characters belong to the text view then, not to the card's own scroller.
        #expect(!card([wide, wide], language: "text", mode: .editing).scrollsHorizontally)
    }

    @Test func aWideCodeCardScrollsHorizontallyToo() {
        // The widening. A labelled block and a block whose fence named nothing are both code, and both
        // are governed by the same "never wrap" sentence a diagram is.
        #expect(card([wideCode, wideCode], language: "python").scrollsHorizontally)
        #expect(card([wideCode, wideCode], language: nil).scrollsHorizontally)
    }

    @Test func aCodeCardThatFitsStillDoesNotOfferToScroll() {
        // Same bar as a diagram's: nothing to scroll means no gesture is claimed, so a sideways twitch
        // over a short function never fights the note's own scrolling.
        #expect(!card(["def hello():", "    pass"], language: "python").scrollsHorizontally)
    }

    @Test func aCodeCardBeingEditedDoesNotOfferToScroll() {
        // Unchanged by the widening, and the reason it is unchanged is unchanged: while the block is
        // being typed into, its characters belong to the text view and the caret is what moves.
        #expect(!card([wideCode, wideCode], language: "python", mode: .editing).scrollsHorizontally)
    }

    @Test func aWideCodeCardStaysInBoundsAndKeepsItsCharacters() {
        // The offset is presentation only. Nothing here reaches `Note.body`, and nothing is persisted.
        let view = card([wideCode, wideCode], language: "python")
        let before = view.drawnCode?.string
        #expect(view.horizontalOffset == 0)
        view.scrollHorizontally(by: 90)
        #expect(view.horizontalOffset == 90)
        view.scrollHorizontally(by: 100_000)
        #expect(view.horizontalOffset == view.maxHorizontalOffset)
        #expect(view.maxHorizontalOffset > 0)
        view.scrollHorizontally(by: -100_000)
        #expect(view.horizontalOffset == 0)
        #expect(view.drawnCode?.string == before)
    }

    @Test func aGestureStartingOnCopyCodeIsNotAScroll() {
        // Copy Code wins for exactly the reason Copy Text does: a drag that starts on a button is a
        // cancelled tap.
        let view = card([wideCode, wideCode], language: "python")
        let overCopy = CGPoint(x: view.bounds.width - 60, y: 22)
        #expect(!view.acceptsHorizontalPan(at: overCopy))
        #expect(view.acceptsHorizontalPan(at: CGPoint(x: view.bounds.midX, y: view.bounds.midY)))
    }

    @Test func aWideCodeCardIsStillTransparentToTaps() {
        // The widening must not cost the block its way in: a tap still has to reach the source and put
        // the caret in the code, which is the whole reason the gesture lives on the text view.
        let view = card([wideCode, wideCode], language: "python")
        let overCode = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        #expect(view.hitTest(overCode, with: nil) == nil)
    }

    // MARK: The gesture rule, as arithmetic

    @Test func aClearlyHorizontalDragIsClaimed() {
        #expect(CardPanRule.claimsGesture(translation: CGPoint(x: -600, y: 20), canScroll: true))
        #expect(CardPanRule.claimsGesture(translation: CGPoint(x: 450, y: -60), canScroll: true))
    }

    @Test func aVerticalDragIsNeverClaimed() {
        // The note must keep scrolling exactly as it does everywhere else.
        #expect(!CardPanRule.claimsGesture(translation: CGPoint(x: 20, y: -800), canScroll: true))
        #expect(!CardPanRule.claimsGesture(translation: CGPoint(x: -40, y: 900), canScroll: true))
    }

    @Test func anAmbiguousDiagonalIsNeverClaimed() {
        // Ties go to the note. A gesture that is not clearly horizontal is not a request to scroll a
        // diagram, and guessing here would make the page feel like it was fighting the finger.
        #expect(!CardPanRule.claimsGesture(translation: CGPoint(x: 300, y: 300), canScroll: true))
        #expect(!CardPanRule.claimsGesture(translation: CGPoint(x: 400, y: 260), canScroll: true))
    }

    @Test func aFingerThatHasBarelyMovedIsNeverClaimed() {
        // A tap must stay a tap — it is the only way into the block underneath.
        #expect(!CardPanRule.claimsGesture(translation: .zero, canScroll: true))
        #expect(!CardPanRule.claimsGesture(translation: CGPoint(x: 4, y: 2), canScroll: true))
    }

    @Test func nothingIsClaimedWhenTheCardCannotScroll() {
        #expect(!CardPanRule.claimsGesture(translation: CGPoint(x: -900, y: 0), canScroll: false))
    }

    // MARK: Where the offset may go

    @Test func scrollingMovesTheDrawingAndStaysInBounds() {
        let view = card([wide, wide], language: "text")
        #expect(view.horizontalOffset == 0)
        view.scrollHorizontally(by: 120)
        #expect(view.horizontalOffset == 120)
        // Never past the end…
        view.scrollHorizontally(by: 100_000)
        #expect(view.horizontalOffset == view.maxHorizontalOffset)
        #expect(view.maxHorizontalOffset > 0)
        // …and never before the beginning.
        view.scrollHorizontally(by: -100_000)
        #expect(view.horizontalOffset == 0)
    }

    @Test func aCardThatFitsNeverMoves() {
        let view = card(["apps/"], language: "text")
        view.scrollHorizontally(by: 500)
        #expect(view.horizontalOffset == 0)
        #expect(view.maxHorizontalOffset == 0)
    }

    // MARK: What must not change

    @Test func theCardIsStillTransparentToTaps() {
        // The whole reason the gesture lives on the text view. If this ever returns a view, a tap can
        // no longer reach the source underneath and the block loses its way in.
        let view = card([wide, wide], language: "text")
        let overCode = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        #expect(view.hitTest(overCode, with: nil) == nil)
    }

    @Test func copyTextIsStillDirectlyTappable() {
        let view = card([wide, wide], language: "text")
        let overCopy = CGPoint(x: view.bounds.width - 60, y: 22)
        #expect(view.hitTest(overCopy, with: nil) is UIButton)
        #expect(view.claimsTouch(at: overCopy))
    }

    @Test func aGestureStartingOnCopyTextIsNotAScroll() {
        // Copy wins when the touch begins on the button, however the finger moves afterwards.
        let view = card([wide, wide], language: "text")
        let overCopy = CGPoint(x: view.bounds.width - 60, y: 22)
        #expect(!view.acceptsHorizontalPan(at: overCopy))
        #expect(view.acceptsHorizontalPan(at: CGPoint(x: view.bounds.midX, y: view.bounds.midY)))
    }

    @Test func scrollingNeverTouchesTheCharacters() {
        let view = card([wide, wide], language: "text")
        let before = view.drawnCode?.string
        view.scrollHorizontally(by: 200)
        #expect(view.drawnCode?.string == before)
    }
}
