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

    /// And the marker is never drawn: the bare visible text carries no marker characters. This is the
    /// *stripped* projection — what `Note.isEmptyDraft` weighs. What a reader is shown and what
    /// VoiceOver is told are built from it rather than being it, and carry the visible glyph or the
    /// spoken state instead (`StructuredTextExport.previewText` / `.spokenText`).
    @Test func visibleTextDropsEveryMarker() {
        let source = "# Head\n- One\n1. Two\n- [ ] Three"
        #expect(MarkupDocument(source).visibleText() == "Head\nOne\nTwo\nThree")
    }
}

/// What the body text view hands to VoiceOver.
///
/// The backing store holds the source, so the value has to be built rather than read — and *what* is
/// built is the whole question. It used to be `MarkupDocument.visibleText()`, the note with every
/// marker removed, which left a ticked and an unticked box sounding identical and a table reading its
/// own pipes aloud. State carried by a drawn glyph and nothing else is exactly what
/// docs/03-design-system.md forbids.
@MainActor
struct StructuredTextViewAccessibilityTests {

    private func view(_ source: String) -> StructuredTextView {
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        tv.text = source
        return tv
    }

    @Test func aTickedAndAnUntickedItemDoNotSoundAlike() {
        #expect(view("- [ ] Call Ravi").accessibilityValue != view("- [x] Call Ravi").accessibilityValue)
    }

    @Test func theTickStateIsAnnouncedInWords() {
        #expect(view("- [ ] Call Ravi").accessibilityValue == "Unchecked, Call Ravi")
        #expect(view("- [x] Call Ravi").accessibilityValue == "Checked, Call Ravi")
    }

    @Test func aBulletIsAnnouncedRatherThanSilent() {
        #expect(view("- Eggs").accessibilityValue == "Bullet, Eggs")
    }

    @Test func noSourceMarkerIsHandedToVoiceOver() {
        let spoken = view("# Head\n- One\n- [ ] Two").accessibilityValue ?? ""
        #expect(!spoken.contains("# "))
        #expect(!spoken.contains("- "))
    }

    @Test func aTablesPipesAreNeverSpoken() {
        let spoken = view("| Day | Park |\n| --- | --- |\n| 1 | Kenai |").accessibilityValue ?? ""
        #expect(!spoken.contains("|"))
        #expect(!spoken.contains("---"))
        #expect(spoken.contains("Kenai"), "the cells themselves must still be read")
    }
}

/// The checkbox's *target*, which is not the same thing as the checkbox.
///
/// The drawn box is small on purpose — a marker is not the sentence — but the region that toggles it
/// was the 28-point gutter and nothing more, well under the ~44 points RULES.md §4 asks of a primary
/// touch target. Ticking items off is the whole point of a checklist, and a missed tap costs a caret
/// and a keyboard.
///
/// Width was the first half of that and height is the second: a checklist row is a line of body type,
/// about 24 points tall, so the target was 44×24 until the band was grown around the line
/// (`StructuredTextStyle.checkboxHitHeight`). Growing it makes neighbouring bands overlap, and these
/// tests are mostly about the one thing that then matters — that an overlap resolves to exactly one
/// item, every time, at every point in it, including the shared edge.
@MainActor
struct ChecklistHitTargetTests {

    private func editor(_ source: String) -> (UITextView, BodyTextView.Coordinator) {
        let parent = BodyTextView(text: .constant(source),
                                  selectedRange: .constant(NSRange(location: 0, length: 0)),
                                  isFocused: .constant(false),
                                  isEditable: true,
                                  keyboardAppearance: .light)
        let coordinator = BodyTextView.Coordinator(parent)
        let tv = StructuredTextView.make()
        tv.delegate = coordinator
        tv.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        tv.font = StructuredTextStyle.bodyFont()
        tv.text = source
        coordinator.restyle(tv)
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        return (tv, coordinator)
    }

    /// Measured against the line's own drawn band, so the number is the target a finger actually gets.
    private func targetWidth(in source: String) -> CGFloat {
        let (tv, coordinator) = editor(source)
        let glyph = tv.layoutManager.glyphIndexForCharacter(at: 0)
        let y = tv.layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).midY
            + tv.textContainerInset.top
        var widest: CGFloat = 0
        for x in stride(from: CGFloat(0), through: 120, by: 1)
        where coordinator.checkboxLine(in: tv, at: CGPoint(x: x, y: y)) != nil {
            widest = x
        }
        return widest
    }

    @Test func theToggleTargetIsAtLeastFortyFourPointsWide() {
        let width = targetWidth(in: "- [ ] Call Ravi")
        #expect(width >= 44, "the checkbox target is only \(width) pt wide, under the 44 pt floor (§4)")
    }

    @Test func aTapOnTheBoxItselfStillToggles() {
        let (tv, coordinator) = editor("- [ ] Call Ravi")
        #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: 10)) != nil)
    }

    /// The target is the checkbox's, not the sentence's: a tap out in the words still places a caret.
    @Test func aTapInTheWordsIsNotAToggle() {
        let (tv, coordinator) = editor("- [ ] Call Ravi")
        #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 120, y: 10)) == nil)
    }

    /// And only a checklist has one. A bullet's gutter is not a control.
    @Test func aBulletHasNoToggleTarget() {
        let (tv, coordinator) = editor("- Eggs")
        #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: 10)) == nil)
    }

    /// The far edge of the overhang. Wide enough to clear the floor, and not one point wider — the
    /// words past it are the note, and a tap in them places a caret like a tap in any other line.
    @Test func theOverhangStopsAtTheTargetWidth() {
        let (tv, coordinator) = editor("- [ ] Call Ravi")
        #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 45, y: 10)) == nil)
    }

    // MARK: Height

    /// The source offset each checklist item starts at, in document order.
    private func itemOffsets(in source: String) -> [Int] {
        MarkupDocument(source).lines.compactMap { line in
            if case .checklist = line.kind { return line.sourceRange.location }
            return nil
        }
    }

    /// The line fragment of the line starting at `offset`, in text-*view* coordinates.
    private func fragment(_ tv: UITextView, at offset: Int) -> CGRect {
        var rect = tv.layoutManager.lineFragmentRect(
            forGlyphAt: tv.layoutManager.glyphIndexForCharacter(at: offset), effectiveRange: nil)
        rect.origin.y += tv.textContainerInset.top
        return rect
    }

    /// The height of the unbroken run of touches at `x` that resolve to the item at `offset` — the
    /// target a finger actually gets, not the band the geometry describes.
    ///
    /// Each edge is found by bisection rather than by stepping towards it. A stepped scan reports the
    /// sampling resolution as much as the target: at half-point steps a genuine 44.0pt run measures
    /// 43.5, which is a test failing on its own ruler. Contiguity is not assumed here — it is proved
    /// separately by `noTouchInsideAChecklistFallsThrough` and `everyTouchInAThreeItemChecklist…`.
    private func targetHeight(ofItemAt offset: Int, in source: String, x: CGFloat = 10) -> CGFloat {
        let (tv, coordinator) = editor(source)
        let centre = fragment(tv, at: offset).midY
        func hits(_ y: CGFloat) -> Bool {
            coordinator.checkboxLine(in: tv, at: CGPoint(x: x, y: y))?.sourceRange.location == offset
        }
        guard hits(centre) else { return 0 }

        func reach(_ direction: CGFloat) -> CGFloat {
            var inside: CGFloat = 0
            var outside: CGFloat = 1
            while outside < 400, hits(centre + direction * outside) {
                inside = outside
                outside *= 2
            }
            for _ in 0..<24 {
                let mid = (inside + outside) / 2
                if hits(centre + direction * mid) { inside = mid } else { outside = mid }
            }
            return inside
        }
        return reach(-1) + reach(1)
    }

    /// Whether a measured run meets the floor §4 sets.
    ///
    /// The slack is the measurement's, not a concession on the rule: `targetHeight` closes on each
    /// edge from the inside, so a true 44.0pt run measures 43.999999. A thousandth of a point is four
    /// orders of magnitude below anything a finger could tell apart.
    private func meetsFloor(_ run: CGFloat) -> Bool {
        run >= StructuredTextStyle.checkboxHitHeight - 0.001
    }

    /// A checklist item with nothing above or below it takes the space it needs and clears the floor.
    @Test func aLoneItemsTargetIsFortyFourPointsTall() {
        let height = targetHeight(ofItemAt: 0, in: "- [ ] Call Ravi")
        #expect(meetsFloor(height), "the target is only \(height) pt tall, under the 44 pt floor (§4)")
    }

    /// And so does the last item of a note, which is where a checklist usually ends up.
    @Test func theLastItemOfANoteClearsTheFloor() {
        let source = "Before I forget\n- [ ] Call Ravi"
        let height = targetHeight(ofItemAt: itemOffsets(in: source)[0], in: source)
        #expect(meetsFloor(height), "the target is only \(height) pt tall, under the 44 pt floor (§4)")
    }

    // MARK: One item, always

    /// Three items stacked. Sweeping a finger down the gutter must enter each item once, in order —
    /// an ambiguous overlap would show up here as an item entered, left, and entered again.
    @Test func everyTouchInAThreeItemChecklistResolvesToOneItem() {
        let source = "- [ ] One\n- [x] Two\n- [ ] Three"
        let (tv, coordinator) = editor(source)
        var visited: [Int] = []
        for y in stride(from: CGFloat(-40), through: 240, by: 0.5) {
            guard let line = coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: y)) else { continue }
            if visited.last != line.sourceRange.location { visited.append(line.sourceRange.location) }
        }
        #expect(visited == itemOffsets(in: source), "resolution wandered between items: \(visited)")
    }

    /// Nothing falls *between* two items either: the run of items is continuous, so a touch aimed at
    /// the checklist always reaches a checkbox rather than the caret.
    @Test func noTouchInsideAChecklistFallsThrough() {
        let source = "- [ ] One\n- [x] Two\n- [ ] Three"
        let (tv, coordinator) = editor(source)
        let offsets = itemOffsets(in: source)
        let top = fragment(tv, at: offsets.first!).minY
        let bottom = fragment(tv, at: offsets.last!).maxY
        for y in stride(from: top + 0.5, to: bottom, by: 0.5) {
            #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: y)) != nil,
                    "a touch at \(y) reached no item at all")
        }
    }

    /// The shared edge belongs to one item and keeps belonging to it. Ties go to the earlier item, so
    /// the boundary is a decision rather than whichever way the arithmetic happens to fall.
    @Test func theBoundaryBetweenTwoItemsIsDecided() {
        let source = "- [ ] One\n- [x] Two\n- [ ] Three"
        let (tv, coordinator) = editor(source)
        let offsets = itemOffsets(in: source)
        let edge = fragment(tv, at: offsets[1]).minY

        func item(at y: CGFloat) -> Int? {
            coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: y))?.sourceRange.location
        }
        #expect(item(at: edge) == offsets[0], "the earlier item takes the shared edge")
        #expect(item(at: edge) == item(at: edge), "and gives the same answer twice")
        #expect(item(at: edge - 0.5) == offsets[0])
        #expect(item(at: edge + 0.5) == offsets[1])
    }

    /// Rule one, stated directly: a touch anywhere inside an item's own line is that item's, top to
    /// bottom, ticked or not. This is what makes a stack of items unstealable from each other.
    @Test func aTouchInsideAnItemsOwnLineBelongsToThatItem() {
        let source = "- [ ] One\n- [x] Two\n- [ ] Three"
        let (tv, coordinator) = editor(source)
        for offset in itemOffsets(in: source) {
            let rect = fragment(tv, at: offset)
            for fraction in [0.05, 0.5, 0.95] as [CGFloat] {
                let y = rect.minY + rect.height * fraction
                #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: y))?.sourceRange.location == offset,
                        "the item at \(offset) lost a touch \(fraction) of the way down its own line")
            }
        }
    }

    /// The band is measured from the lines themselves rather than from a table of numbers, so the
    /// rules have to hold when the lines around an item are not the same height as the item — a
    /// heading above it, a paragraph below. The same generality is what carries them through Dynamic
    /// Type, which a unit test cannot vary here: the fonts come from the process-wide content size
    /// category, so the text size pass belongs to the accessibility UI audits and the device run.
    @Test func theRulesHoldAmongLinesOfDifferentHeights() {
        let source = "# Trip\n- [ ] Passport\n- [ ] Charger\nBook the taxi the night before"
        let (tv, coordinator) = editor(source)
        for offset in itemOffsets(in: source) {
            let rect = fragment(tv, at: offset)
            for fraction in [0.05, 0.5, 0.95] as [CGFloat] {
                let y = rect.minY + rect.height * fraction
                #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: y))?
                    .sourceRange.location == offset,
                        "the item at \(offset) lost a touch \(fraction) of the way down its own line")
            }
        }
    }

    /// The case the band alone could never reach: an item with checklist items above *and* below it.
    ///
    /// Rule 1 gives each line to itself, so a middle item's target is exactly its line — which is why
    /// no hit test could lift it while the rows were 24 points apart. The row itself carries the 44
    /// points now (`StructuredTextStyle.checklistLeading`), so every item in a run clears the floor,
    /// not only the ones with empty space beside them.
    @Test func everyItemInARunClearsTheFloor() {
        let source = "Launch checklist\n- [ ] One\n- [x] Two\n- [ ] Three\n1. Anchorage"
        for offset in itemOffsets(in: source) {
            let run = targetHeight(ofItemAt: offset, in: source)
            #expect(meetsFloor(run), "the item at \(offset) has a \(run) pt target, under the floor (§4)")
        }
    }

    /// The hard case, named so it cannot be lost among the others.
    ///
    /// An item with a checklist item directly above *and* directly below it has no empty space on
    /// either side to borrow, so it is the one position no hit test could ever have lifted to 44pt.
    /// It is the case the row height exists for, and it is measured on its own.
    @Test func theMiddleOfThreeConsecutiveItemsClearsTheFloor() {
        let source = "- [ ] One\n- [x] Two\n- [ ] Three"
        let middle = itemOffsets(in: source)[1]
        let run = targetHeight(ofItemAt: middle, in: source)
        #expect(meetsFloor(run), "the middle of three items has a \(run) pt target, under the floor (§4)")
    }

    /// And the leading stays where it belongs. A checkbox is a control and takes the 44 points §4 asks
    /// for; every other line on the page is prose, which does not — a note whose paragraphs had been
    /// spaced out to suit a checkbox would be an interface winning over a note (RULES.md, primary rule).
    @Test func onlyChecklistLinesCarryTheExtraLeading() {
        let source = "Launch checklist\n- [ ] One\n- Eggs\n1. Anchorage\nA closing thought"
        let (tv, _) = editor(source)
        let doc = MarkupDocument(source)
        let plain = fragment(tv, at: doc.lines[0].sourceRange.location).height

        for (index, line) in doc.lines.enumerated() {
            let height = fragment(tv, at: line.sourceRange.location).height
            if case .checklist = line.kind {
                #expect(height >= 44, "a checklist row is only \(height) pt tall")
            } else {
                #expect(abs(height - plain) <= 2.5,
                        "line \(index) (\(line.kind)) is \(height) pt against prose at \(plain) pt")
            }
        }
    }

    // MARK: What the band may not take

    /// A band grows into the line above or below it, and that line is usually a sentence someone still
    /// has to be able to put a caret in. It may take at most half of one, so the half the words
    /// themselves sit in is never a checkbox.
    @Test func aParagraphBesideAChecklistKeepsTheHalfItsWordsSitIn() {
        let source = "Before I forget\n- [ ] Call Ravi"
        let (tv, coordinator) = editor(source)
        let rect = fragment(tv, at: 0)
        for fraction in [0.05, 0.2, 0.4] as [CGFloat] {
            let y = rect.minY + rect.height * fraction
            #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: y)) == nil,
                    "the checkbox below took the paragraph's own words at \(fraction)")
        }
    }

    /// The space above the first line belongs to the page's own chrome. The date and title scroll with
    /// the body, so the text view reserves room for them in its top inset (`NotePageView`) — and a
    /// touch up there is a touch on the header, not on the first item's box.
    ///
    /// Before the band was bounded, *every* point above the text resolved to the first line, so
    /// tapping the date line ticked the first item of the note. `testTappingCheckboxToggles` had been
    /// passing on exactly that: it aimed 34 points above the title and still toggled (2026-08-21).
    @Test func aTouchInThePagesHeaderSpaceIsNotAToggle() {
        let (tv, coordinator) = editor("- [ ] Call Ravi")
        tv.textContainerInset.top = 74      // about what a date and a title reserve
        tv.layoutManager.ensureLayout(for: tv.textContainer)

        #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: 20)) == nil,
                "a touch in the header space ticked the first item")
        #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: 84)) != nil,
                "and the first line itself is still a target")
    }

    /// And a bullet next to a checklist is still not a control, however close it sits.
    @Test func aBulletBesideAChecklistIsStillNotAControl() {
        let source = "- Eggs\n- [ ] Call Ravi"
        let (tv, coordinator) = editor(source)
        let rect = fragment(tv, at: 0)
        #expect(coordinator.checkboxLine(in: tv, at: CGPoint(x: 10, y: rect.minY + rect.height * 0.2)) == nil)
    }
}

// MARK: - The circle

/// A checklist marker is a **circle**, not a box (2026-08-31, docs/03-design-system.md "How structure
/// renders"). A square reads as a task manager, which a checklist here is explicitly not
/// (docs/02-features.md Milestone A); a thin ring beside the words reads as a note with something to
/// tick off. The change is rendering only — the source still holds `- [ ] ` / `- [x] `, which these
/// tests keep typing.
///
/// Most of this is measured off pixels rather than asserted about symbol names, because the claim is
/// what a reader sees: a corner that stays empty is what separates a circle from a box.
@MainActor
struct ChecklistCircleTests {

    private var body: UIFont { StructuredTextStyle.bodyFont() }

    // MARK: Geometry

    /// Big enough to aim at, small enough to stay a marker. The gutter is 28pt and the words start
    /// there, so the circle is sized from the type rather than from a number picked in isolation.
    @Test func theCircleIsAMarkerNotAButton() {
        let d = StructuredTextStyle.checkboxDiameter(for: body)
        #expect(d >= 16 && d <= 22, "diameter \(d) is outside the 16–22pt band")
    }

    /// It is drawn from the line's font, so it grows with Dynamic Type like the bullet and the number
    /// beside it rather than tracking a second, fixed idea of its size.
    @Test func theCircleTracksDynamicType() {
        let large = UIFont.preferredFont(
            forTextStyle: .body,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        )
        #expect(StructuredTextStyle.checkboxDiameter(for: large) > StructuredTextStyle.checkboxDiameter(for: body))
    }

    /// A circle's frame is square, and it stops short of the words: the gap between the ring and the
    /// first letter is what keeps a checklist reading as text with marks beside it, not marks with
    /// captions.
    @Test func theCircleLeavesRoomBeforeTheWords() {
        let frame = StructuredTextStyle.checkboxFrame(x: 0, baselineY: 100, font: body)
        #expect(frame.width == frame.height)
        #expect(frame.maxX <= StructuredTextStyle.listIndent - 6,
                "the circle ends at \(frame.maxX), leaving under 6pt before the text at \(StructuredTextStyle.listIndent)")
        #expect(frame.minX >= 1)
    }

    // MARK: Colour

    /// The tick is drawn *on* the accent fill, so it is measured against the fill, not the canvas.
    @Test(arguments: [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark])
    func theTickClearsTheContrastFloorAgainstItsFill(style: UIUserInterfaceStyle) throws {
        let lm = try #require(StructuredTextView.make().layoutManager as? StructuredLayoutManager)
        let ratio = contrast(lm.tickColor, lm.accentColor, in: style)
        #expect(ratio >= 4.5, "the tick sits at \(ratio):1 on its fill, under the 4.5:1 floor (§6)")
    }

    /// A ticked item's words step back — but to the secondary token, never to a custom alpha. "Muted"
    /// has to stay legible: a ticked item is still the note, and the reader may want to untick it.
    @Test(arguments: [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark])
    func aTickedItemsWordsAreMutedNotFaded(style: UIUserInterfaceStyle) {
        let checked = contrast(UIColor(Color.ds.textSecondary), UIColor(Color.ds.canvas), in: style)
        let unchecked = contrast(UIColor(Color.ds.textPrimary), UIColor(Color.ds.canvas), in: style)
        #expect(checked >= 4.5, "a ticked item reads at \(checked):1, under the 4.5:1 floor (§6)")
        #expect(checked < unchecked, "a ticked item is as loud as an unticked one")
    }

    /// And that is the colour the words actually get, through the one definition of a line's
    /// attributes, so the styler and the typing attributes cannot disagree about a ticked line.
    @Test func onlyATickedItemsWordsTakeTheMutedColour() {
        let storage = NSTextStorage(string: "- [ ] One\n- [x] Two\n- Three")
        StructuredTextStyler.apply(to: storage, textColor: .black, checkedTextColor: .red)
        let lines = MarkupDocument(storage.string).lines
        func colour(ofLine i: Int) -> UIColor? {
            storage.attribute(.foregroundColor, at: lines[i].contentStart, effectiveRange: nil) as? UIColor
        }
        #expect(colour(ofLine: 0) == .black)
        #expect(colour(ofLine: 1) == .red)
        #expect(colour(ofLine: 2) == .black)

        let typing = StructuredTextStyle.attributes(for: .checklist(checked: true), isFirstLine: false,
                                                    textColor: .black, checkedTextColor: .red)
        #expect(typing[.foregroundColor] as? UIColor == .red)
    }

    /// Read off the real editor, not off a token: the wiring is the claim.
    @Test func theEditorMutesATickedItemToTextSecondary() {
        let source = "- [x] Two"
        let parent = BodyTextView(text: .constant(source),
                                  selectedRange: .constant(NSRange(location: 0, length: 0)),
                                  isFocused: .constant(false),
                                  isEditable: true,
                                  keyboardAppearance: .light)
        let coordinator = BodyTextView.Coordinator(parent)
        let tv = StructuredTextView.make()
        tv.delegate = coordinator
        tv.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        tv.text = source
        coordinator.restyle(tv)
        let start = MarkupDocument(source).lines[0].contentStart
        let drawn = tv.textStorage.attribute(.foregroundColor, at: start, effectiveRange: nil) as? UIColor
        #expect(drawn == UIColor(Color.ds.textSecondary))
        #expect(drawn != UIColor(Color.ds.textTertiary), "tertiary is the code-fence colour, and too faint for words")
    }

    // MARK: Pixels

    /// A box paints its corners; a circle leaves them empty. That one pixel is the whole difference.
    @Test(arguments: [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark])
    func anUntickedItemIsARingNotABox(style: UIUserInterfaceStyle) throws {
        let (raster, frame) = try rasterise("- [ ] One", style: style)
        #expect(raster.alpha(at: CGPoint(x: frame.minX + 1, y: frame.minY + 1)) < 0.05,
                "the corner of an unticked marker is painted — that is a box")
        #expect(raster.alpha(at: CGPoint(x: frame.minX + 0.5, y: frame.midY)) > 0.9,
                "nothing is drawn where the ring should be")
        #expect(raster.alpha(at: CGPoint(x: frame.midX, y: frame.midY)) < 0.05,
                "an unticked circle has a transparent centre")
    }

    /// Ticked: a solid accent circle, still with empty corners, carrying a tick in the on-accent colour.
    @Test(arguments: [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark])
    func aTickedItemIsAFilledCircleWithATick(style: UIUserInterfaceStyle) throws {
        let (raster, frame) = try rasterise("- [x] One", style: style)
        let lm = try #require(StructuredTextView.make().layoutManager as? StructuredLayoutManager)
        let accent = lm.accentColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        let tick = lm.tickColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))

        #expect(raster.alpha(at: CGPoint(x: frame.minX + 1, y: frame.minY + 1)) < 0.05,
                "the corner of a ticked marker is painted — that is a box")
        // Well inside the circle and well clear of the tick, which sits in the middle half.
        let edge = CGPoint(x: frame.minX + 1.5, y: frame.midY)
        #expect(raster.matches(accent, at: edge), "the fill at \(edge) is not the accent")
        #expect(raster.contains(tick, in: frame), "no on-accent tick was drawn inside the circle")
    }

    // MARK: Helpers

    /// Draws the first line the way the editor does — through the layout manager, with the design
    /// system's colours resolved for `style` — and returns the marker's frame in the same space.
    private func rasterise(_ source: String, style: UIUserInterfaceStyle) throws -> (Raster, CGRect) {
        let tv = laidOutView(source)
        let lm = try #require(tv.layoutManager as? StructuredLayoutManager)
        let line = MarkupDocument(source).lines[0]
        let glyph = lm.glyphIndexForCharacter(at: line.sourceRange.location)
        let fragmentRect = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let baselineY = fragmentRect.minY + lm.location(forGlyphAt: glyph).y
        let frame = StructuredTextStyle.checkboxFrame(x: 0, baselineY: baselineY, font: body)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let size = CGSize(width: 120, height: max(60, fragmentRect.maxY + 10))
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UITraitCollection(userInterfaceStyle: style).performAsCurrent {
                let range = lm.glyphRange(for: tv.textContainer)
                lm.drawBackground(forGlyphRange: range, at: .zero)
                lm.drawGlyphs(forGlyphRange: range, at: .zero)
            }
        }
        return (try Raster(try #require(image.cgImage), scale: 2), frame)
    }

    /// Straight RGBA bytes in sRGB, so a pixel can be compared with a resolved token.
    private struct Raster {
        let width: Int, height: Int, scale: CGFloat
        let bytes: [UInt8]

        init(_ cg: CGImage, scale: CGFloat) throws {
            width = cg.width; height = cg.height; self.scale = scale
            var data = [UInt8](repeating: 0, count: width * height * 4)
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let ctx = try #require(CGContext(
                data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            bytes = data
        }

        /// Premultiplied RGBA, 0…1, at a point in *points* (the renderer's flipped space).
        private func rgba(at p: CGPoint) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
            let x = min(max(Int(p.x * scale), 0), width - 1)
            let y = min(max(Int(p.y * scale), 0), height - 1)
            let i = (y * width + x) * 4
            return (CGFloat(bytes[i]) / 255, CGFloat(bytes[i + 1]) / 255,
                    CGFloat(bytes[i + 2]) / 255, CGFloat(bytes[i + 3]) / 255)
        }

        func alpha(at p: CGPoint) -> CGFloat { rgba(at: p).a }

        func matches(_ colour: UIColor, at p: CGPoint) -> Bool {
            let px = rgba(at: p)
            guard px.a > 0.95 else { return false }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            colour.getRed(&r, green: &g, blue: &b, alpha: &a)
            return abs(px.r - r) < 0.04 && abs(px.g - g) < 0.04 && abs(px.b - b) < 0.04
        }

        func contains(_ colour: UIColor, in rect: CGRect) -> Bool {
            stride(from: rect.minY, to: rect.maxY, by: 0.5).contains { y in
                stride(from: rect.minX, to: rect.maxX, by: 0.5).contains { x in
                    matches(colour, at: CGPoint(x: x, y: y))
                }
            }
        }
    }
}
