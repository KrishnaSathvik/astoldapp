import Testing
import Foundation
import UIKit
import SwiftUI
@testable import Yourly

/// The editor half of "a caret never settles in hidden syntax".
///
/// The block-marker guard has existed since markers did: a character inserted in front of `- ` turns a
/// bullet into the literal text "X- Eggs". Links generalised hidden syntax without generalising that
/// guard, and the same stray character landing in `](https://…)` is worse than a lost bullet — it
/// dismantles the link, so the note loses the destination it was carrying *and* shows the reader the
/// brackets it was never meant to (RULES.md §4).
@MainActor
struct LinkCaretHardeningTests {

    private let source = "Go [there](https://astold.app) now"

    /// A coordinator and a text view wired the way the editor wires them.
    private func editor(_ text: String, caret: NSRange) -> (BodyTextView.Coordinator, StructuredTextView) {
        var body = text
        var range = caret
        var focused = true
        let parent = BodyTextView(text: Binding(get: { body }, set: { body = $0 }),
                                  selectedRange: Binding(get: { range }, set: { range = $0 }),
                                  isFocused: Binding(get: { focused }, set: { focused = $0 }),
                                  isEditable: true,
                                  keyboardAppearance: .light)
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 360, height: 800)
        tv.textContainer.size = CGSize(width: 360, height: CGFloat.greatestFiniteMagnitude)
        tv.text = text
        tv.selectedRange = caret
        return (parent.makeCoordinator(), tv)
    }

    /// The middle of `](https://astold.app)` — an offset with no glyph of its own.
    private var insideTheSyntax: Int {
        let run = MarkupDocument(source).lines[0].hiddenRuns.first { $0.length > 1 }!
        return run.location + run.length / 2
    }

    @Test func theCaretIsMovedOutOfHiddenLinkSyntax() {
        let (co, tv) = editor(source, caret: NSRange(location: insideTheSyntax, length: 0))
        co.textViewDidChangeSelection(tv)
        #expect(MarkupDocument(tv.text).lines[0].hiddenRun(containing: tv.selectedRange.location) == nil,
                "the caret was left at \(tv.selectedRange.location), inside the link's syntax")
    }

    @Test func aCharacterArrivingInsideTheSyntaxNeverLandsThere() {
        // Dictation, a drag and drop, and an autocorrect replacement all supply a range directly —
        // this is the route the marker guard was built for, and it reaches links the same way.
        let (co, tv) = editor(source, caret: NSRange(location: insideTheSyntax, length: 0))
        let allowed = co.textView(tv, shouldChangeTextIn: NSRange(location: insideTheSyntax, length: 0),
                                  replacementText: "X")
        #expect(!allowed, "the insertion was allowed straight into the link's syntax")

        let doc = MarkupDocument(tv.text)
        #expect(doc.links.count == 1, "the link did not survive the insertion")
        #expect(doc.links.first?.destination == "https://astold.app")
        // Immediately after the link's words — outside the syntax, and where the caret was visibly
        // sitting — rather than in the middle of the destination.
        #expect(doc.visibleText() == "Go thereX now")
        // Nothing of the syntax reached the reader.
        #expect(!doc.visibleText().contains("]("))
    }

    @Test func theWordsAroundALinkAreStillOrdinaryPlacesToType() {
        // The guard must be silent everywhere the reader can see, or it would drag the caret around
        // ordinary prose.
        for caret in [0, 3, 5, 30, (source as NSString).length] {
            let (co, tv) = editor(source, caret: NSRange(location: caret, length: 0))
            co.textViewDidChangeSelection(tv)
            #expect(tv.selectedRange.location == caret,
                    "a caret at \(caret) was moved to \(tv.selectedRange.location)")
        }
    }

    @Test func aBareURLTrapsNothingBecauseItHidesNothing() {
        let bare = "Go https://astold.app now"
        for caret in 0...(bare as NSString).length {
            let (co, tv) = editor(bare, caret: NSRange(location: caret, length: 0))
            co.textViewDidChangeSelection(tv)
            #expect(tv.selectedRange.location == caret)
        }
    }

    @Test func aMarkerIsStillGuardedTheWayItAlwaysWas() {
        // The link guard is added alongside the marker guard, not in place of it.
        let (co, tv) = editor("- Eggs", caret: NSRange(location: 0, length: 0))
        co.textViewDidChangeSelection(tv)
        #expect(tv.selectedRange.location == 2)

        let (co2, tv2) = editor("- Eggs", caret: NSRange(location: 0, length: 0))
        #expect(!co2.textView(tv2, shouldChangeTextIn: NSRange(location: 0, length: 0),
                              replacementText: "X"))
        #expect(tv2.text == "- XEggs")
    }
}
