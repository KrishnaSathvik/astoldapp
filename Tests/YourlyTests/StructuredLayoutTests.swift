import Foundation
import Testing
import UIKit
@testable import Yourly

// The rendering layer's half of the structure contract: markers stay invisible, but the line that
// holds one still exists.
//
// These are layout assertions rather than parsing ones because the bug they guard against was
// invisible to the document layer. `DocumentAction.returnEdit` had always produced "- One\n- "
// correctly; the marker glyphs were hidden by being nulled, and a null glyph is *ignored during
// layout*, so a line holding nothing but its marker laid out to no height at all. Pressing Return
// in a list looked like nothing had happened — no new bullet, the caret still on the line above,
// and the new marker painted over the previous item's — while every text assertion passed.

@MainActor
private func laidOutView(_ source: String) -> UITextView {
    let tv = StructuredTextView.make()
    tv.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
    tv.font = StructuredTextStyle.bodyFont()
    tv.text = source
    StructuredTextStyler.apply(to: tv.textStorage, textColor: .label)
    tv.layoutManager.ensureLayout(for: tv.textContainer)
    return tv
}

@MainActor
private func fragment(_ tv: UITextView, lineAt index: Int, in source: String) -> CGRect {
    let line = MarkupDocument(source).lines[index]
    let glyph = tv.layoutManager.glyphIndexForCharacter(at: line.sourceRange.location)
    return tv.layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
}

@MainActor
struct StructuredLayoutTests {

    /// A list item holding only its marker — exactly what Return leaves behind — must occupy a line
    /// of its own, below the item above it.
    @Test(arguments: ["- One\n- ", "1. One\n2. ", "- [ ] One\n- [ ] "])
    func emptyListItemKeepsItsOwnLine(source: String) {
        let tv = laidOutView(source)
        let first = fragment(tv, lineAt: 0, in: source)
        let second = fragment(tv, lineAt: 1, in: source)

        #expect(second.minY > first.minY)
        #expect(second.height > 0)
    }

    /// The same for a heading or subheading applied to a blank line from the Style menu: without its
    /// own line the writer gets no sign the style was applied at all.
    @Test(arguments: ["Intro\n# ", "Intro\n## "])
    func emptyHeadingKeepsItsOwnLine(source: String) {
        let tv = laidOutView(source)
        let first = fragment(tv, lineAt: 0, in: source)
        let second = fragment(tv, lineAt: 1, in: source)

        #expect(second.minY > first.minY)
        #expect(second.height > 0)
    }

    /// Occupying a line must not mean *showing* the marker: its glyphs still take zero horizontal
    /// space, so the first visible character sits exactly at the line's head indent.
    @Test(arguments: ["- One", "1. One", "- [ ] One", "# One", "## One"])
    func markerTakesNoHorizontalSpace(source: String) {
        let tv = laidOutView(source)
        let line = MarkupDocument(source).lines[0]
        let lm = tv.layoutManager

        let markerX = lm.location(forGlyphAt: lm.glyphIndexForCharacter(at: line.sourceRange.location)).x
        let contentX = lm.location(forGlyphAt: lm.glyphIndexForCharacter(at: line.contentStart)).x

        #expect(abs(contentX - markerX) < 0.01)
    }

    /// And the marker is never drawn: the text the reader (and VoiceOver, and the pasteboard) sees
    /// carries no marker characters.
    @Test func visibleTextDropsEveryMarker() {
        let source = "# Head\n- One\n1. Two\n- [ ] Three"
        #expect(MarkupDocument(source).visibleText() == "Head\nOne\nTwo\nThree")
    }
}
