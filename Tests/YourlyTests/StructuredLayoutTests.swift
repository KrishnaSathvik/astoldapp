import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Yourly

private func relativeLuminance(_ color: UIColor, in style: UIUserInterfaceStyle) -> CGFloat {
    let resolved = color.resolvedColor(with: UITraitCollection { $0.userInterfaceStyle = style })
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
    func linear(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
}

private func contrast(_ a: UIColor, _ b: UIColor, in style: UIUserInterfaceStyle) -> CGFloat {
    let (x, y) = (relativeLuminance(a, in: style), relativeLuminance(b, in: style))
    return (max(x, y) + 0.05) / (min(x, y) + 0.05)
}

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

    /// List content is **body text**. A bullet, a number, or a checkbox in front of a line does not
    /// make the line an annotation, and setting list items smaller than the prose around them is the
    /// difference between a note that reads as a page and one that reads as a form.
    @Test func everyListKindIsSetInExactlyTheBodyFont() {
        let body = StructuredTextStyle.font(for: .paragraph)
        for kind in [BlockKind.bullet, .numbered(1), .numbered(12),
                     .checklist(checked: false), .checklist(checked: true)] {
            #expect(StructuredTextStyle.font(for: kind) == body, "\(kind) is not set in body type")
        }
        // The ladder the design system pins: 22-semibold / 17-semibold / 17-regular. Only size and
        // weight may differ, and only for the two heading kinds.
        #expect(StructuredTextStyle.font(for: .heading).pointSize > body.pointSize)
        #expect(StructuredTextStyle.font(for: .subheading).pointSize == body.pointSize)
    }

    /// The same claim measured after layout rather than asserted about fonts: a list line occupies the
    /// same height as a paragraph, so nothing about it renders smaller on the page.
    @Test(arguments: ["- One", "1. One", "- [ ] One"])
    func aListLineIsTheSameHeightAsAParagraph(source: String) {
        let list = fragment(laidOutView(source), lineAt: 0, in: source)
        let plain = fragment(laidOutView("One"), lineAt: 0, in: "One")
        #expect(list.height == plain.height)
    }

    // MARK: The marker is quiet, not faint

    /// The complaint that list markers "look small" was measured and turned out to be contrast, not
    /// size — `aListLineIsTheSameHeightAsAParagraph` above already pins the geometry. The number was
    /// drawn at 70% of the body colour and the empty checkbox at 55%, which put the box at 3.75:1 on
    /// Light canvas: below the floor every other glyph in the app has to clear, and below it in the
    /// one place a writer has to *aim* at with a finger.
    ///
    /// So the floor is asserted here rather than the alpha, because the floor is the actual claim. If
    /// a marker ever needs to be quieter, this test says how quiet it is allowed to get.
    @Test(arguments: [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark])
    func aGutterMarkerClearsTheContrastFloorAgainstTheCanvas(style: UIUserInterfaceStyle) throws {
        let ratio = contrast(try markerColor(), UIColor(Color.ds.canvas), in: style)
        #expect(ratio >= 4.5, "a gutter marker sits at \(ratio):1, under the 4.5:1 floor (§6)")
    }

    /// And it is genuinely quieter than the sentence beside it. A marker at full body colour competes
    /// with the words for the reader's eye, which is the opposite failure and just as wrong.
    @Test(arguments: [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark])
    func aGutterMarkerIsQuieterThanTheTextItSitsBeside(style: UIUserInterfaceStyle) throws {
        let marker = contrast(try markerColor(), UIColor(Color.ds.canvas), in: style)
        let body = contrast(UIColor(Color.ds.textPrimary), UIColor(Color.ds.canvas), in: style)
        #expect(marker < body, "the marker is as loud as the words it introduces")
    }

    /// Read off the real view, not off the token, so this measures the colour the gutter is actually
    /// drawn in — a test that asserted `TextSecondary` against itself would pass with the wiring cut.
    private func markerColor() throws -> UIColor {
        let layoutManager = StructuredTextView.make().layoutManager
        return try #require(layoutManager as? StructuredLayoutManager).markerColor
    }

    /// And the marker is never drawn: the text the reader (and VoiceOver, and the pasteboard) sees
    /// carries no marker characters.
    @Test func visibleTextDropsEveryMarker() {
        let source = "# Head\n- One\n1. Two\n- [ ] Three"
        #expect(MarkupDocument(source).visibleText() == "Head\nOne\nTwo\nThree")
    }
}
