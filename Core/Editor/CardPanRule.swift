import CoreGraphics

// When a drag over a rendered card is a request to scroll that card, and when it is the note being
// scrolled as usual.
//
// This is arithmetic, deliberately kept out of the view so it can be checked without a finger. A
// gesture rule that only exists inside a `UIGestureRecognizerDelegate` can be verified two ways —
// by reasoning, and by a flaky drag in a UI test — and neither is a test.
//
// The bar is set so that **ties go to the note** (added 2026-08-25). A wide preformatted card is the
// only thing on the page that wants a sideways drag; everything else on that surface — placing the
// caret, scrolling the note, tapping Copy Text — already worked, and a rule that guesses would make
// the page feel like it was fighting the finger. So a gesture must be *clearly* horizontal to be
// claimed, and anything short of clear behaves exactly as it did before this existed.
enum CardPanRule {

    /// How much faster horizontally than vertically a drag must travel to count as horizontal.
    ///
    /// 2.0 — about 27° off horizontal. Not 1.0, where a 45° drag is a coin toss tossed while the reader
    /// is trying to scroll the page; and not 1.5 either, which was the first value here and let a drag
    /// 33° off horizontal claim the card. A deliberate sideways swipe sits well inside 27°, while a
    /// page scroll with a bit of sideways drift does not — and when the two are close, the note wins,
    /// because scrolling the page is the gesture the reader makes a hundred times more often.
    static let horizontalDominance: CGFloat = 2.0

    /// Below this the finger has not said anything yet, and a tap must stay a tap — it is the only way
    /// into the block underneath the card. A pan recognizer only asks this question once its own
    /// movement threshold is passed, so by the time it does, a real drag has travelled further.
    static let minimumTravel: CGFloat = 8

    /// Whether this drag scrolls the card rather than the note.
    ///
    /// Judged on **how far the finger has moved**, not how fast. Velocity was the first signal here and
    /// was the wrong one: a recognizer is asked this question at the instant it decides to begin, when
    /// a drag that is about to be unmistakably sideways has barely accelerated — and answering "no"
    /// fails the recognizer for the whole gesture, so there is no second chance later in the same
    /// touch. Distance has already said something by then, and says the same thing for a slow
    /// deliberate drag as for a flick.
    ///
    /// - Parameters:
    ///   - translation: how far the gesture has travelled, in points.
    ///   - canScroll: whether the card under the finger is actually wider than its viewport. A card
    ///     that fits offers nothing to scroll, so it never claims a gesture (a sideways twitch over a
    ///     short diagram must not fight the note's own scrolling).
    static func claimsGesture(translation: CGPoint, canScroll: Bool) -> Bool {
        guard canScroll else { return false }
        let horizontal = abs(translation.x)
        let vertical = abs(translation.y)
        guard horizontal >= minimumTravel else { return false }
        return horizontal > vertical * horizontalDominance
    }
}
