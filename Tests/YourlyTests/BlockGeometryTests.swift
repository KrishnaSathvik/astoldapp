import Testing
import Foundation
import UIKit
import SwiftUI
@testable import Yourly

/// Where a rendered block sits on the page, and that moving focus does not move it.
///
/// The defect these close (2026-08-28): tapping the note's **title** put a visible hole between the
/// title and the code card below it, and the hole grew with the length of the block — 15pt at four
/// lines of code, 39pt at thirty-two. Nothing about the title was wrong. Two faults compounded:
///
///  1. `reserveCards` clamped each of a block's source lines with `maximumLineHeight`, which covers a
///     line's ascent and descent but **not** its font's leading — so the region reserved for a card
///     came out ~1.7pt per line taller than the card, an error with no ceiling.
///  2. `CodeCardPresenter` centred the card in that region, which split the error evenly above and
///     below it and turned half of it into blank page above the card.
///
/// Both are geometry, and geometry is measured. These assertions are the measurements.
@MainActor
struct BlockGeometryTests {

    /// A real note page: a title field whose height sets the body's top inset, and a body text view
    /// with the coordinator's styling and card presenters wired up exactly as `makeUIView` does.
    private func page(_ text: String, title: String = "Sql Questions")
    -> (BodyTextView.Coordinator, StructuredTextView, NotePageView, UIWindow) {
        var body = text
        var range = NSRange(location: 0, length: 0)
        var focused = false
        var titleFocused = false
        var titleValue = title
        let parent = BodyTextView(
            text: Binding(get: { body }, set: { body = $0 }),
            selectedRange: Binding(get: { range }, set: { range = $0 }),
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            isEditable: true,
            keyboardAppearance: .light,
            title: Binding(get: { titleValue }, set: { titleValue = $0 }),
            titleFocused: Binding(get: { titleFocused }, set: { titleFocused = $0 })
        )
        let co = parent.makeCoordinator()
        let tv = StructuredTextView.make()
        tv.delegate = co
        tv.font = StructuredTextStyle.bodyFont()
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        tv.text = text

        let page = NotePageView(textView: tv)
        page.header.titleField.text = title
        page.header.titleField.delegate = co
        co.page = page

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        page.frame = CGRect(x: 0, y: 0, width: 361, height: 700)
        window.addSubview(page)
        window.makeKeyAndVisible()
        page.layoutIfNeeded()
        co.restyle(tv)
        return (co, tv, page, window)
    }

    /// The top of the drawn block, in the note's own content coordinates.
    private func cardTop(in tv: StructuredTextView) -> CGFloat? {
        tv.subviews.compactMap { $0 as? CodeBlockView }.first
            .map { $0.frame.minY - tv.textContainerInset.top }
    }

    private func tableCardTop(in tv: StructuredTextView) -> CGFloat? {
        tv.subviews.compactMap { $0 as? TableCardView }.first
            .map { $0.frame.minY - tv.textContainerInset.top }
    }

    /// The vertical span the block's source lines actually occupy.
    private func span(ofLines lines: ClosedRange<Int>, in tv: StructuredTextView) -> CGFloat {
        tv.layoutManager.ensureLayout(for: tv.textContainer)
        guard let chars = StructuredText.characterRange(ofLines: lines, in: tv.text as NSString)
        else { return 0 }
        let glyphs = tv.layoutManager.glyphRange(forCharacterRange: chars, actualCharacterRange: nil)
        var rect = CGRect.null
        tv.layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, _, _ in
            rect = rect.union(fragment)
        }
        return rect.isNull ? 0 : rect.height
    }

    private func codeNote(lines: Int, language: String = "sql") -> String {
        let code = (1...lines).map { "SELECT column_\($0) FROM some_table WHERE id = \($0);" }
        return (["Prose above.", "", "```" + language] + code + ["```"]).joined(separator: "\n")
    }

    /// Fragment heights are floating-point sums over clamped lines; a point either way is TextKit
    /// rounding, not a block moving.
    private let tolerance: CGFloat = 1.0

    // MARK: The block does not move when focus does

    @Test(arguments: [4, 8, 16, 32, 100])
    func aCodeBlockKeepsItsPositionAcrossFocus(lines: Int) {
        let text = codeNote(lines: lines)
        let (co, tv, page, _) = page(text)
        let insideCode = StructuredText.characterRange(ofLines: 3...3, in: text as NSString)!
        let caret = NSRange(location: insideCode.location + 2, length: 0)

        _ = tv.becomeFirstResponder()
        tv.selectedRange = caret
        co.restyle(tv)
        let editing = cardTop(in: tv)

        _ = page.header.titleField.becomeFirstResponder()
        let reading = cardTop(in: tv)

        _ = tv.becomeFirstResponder()
        tv.selectedRange = caret
        co.restyle(tv)
        let editingAgain = cardTop(in: tv)

        #expect(editing != nil && reading != nil && editingAgain != nil)
        #expect(abs((reading ?? 0) - (editing ?? 0)) <= tolerance,
                "\(lines) lines: the block moved \((reading ?? 0) - (editing ?? 0))pt when the title took focus")
        #expect(abs((editingAgain ?? 0) - (editing ?? 0)) <= tolerance,
                "\(lines) lines: the block did not return to where it was")
    }

    /// The whole point of the bug report: the distance from the prose above the block to the top of
    /// the block must not depend on how many lines the block holds.
    @Test func theGapAboveACodeBlockDoesNotGrowWithItsLength() {
        var tops: [CGFloat] = []
        for lines in [4, 8, 16, 32, 100] {
            let text = codeNote(lines: lines)
            let (_, tv, page, _) = page(text)
            _ = page.header.titleField.becomeFirstResponder()
            tops.append(cardTop(in: tv) ?? -1)
        }
        let spread = (tops.max() ?? 0) - (tops.min() ?? 0)
        #expect(spread <= tolerance,
                "the block's top drifted \(spread)pt across block lengths: \(tops)")
    }

    @Test func aPreformattedBlockKeepsItsPositionAcrossFocus() {
        let text = codeNote(lines: 12, language: CodeBlock.preformattedLanguage)
        let (co, tv, page, _) = page(text)
        let insideCode = StructuredText.characterRange(ofLines: 3...3, in: text as NSString)!
        let caret = NSRange(location: insideCode.location + 2, length: 0)

        _ = tv.becomeFirstResponder()
        tv.selectedRange = caret
        co.restyle(tv)
        let editing = cardTop(in: tv)

        _ = page.header.titleField.becomeFirstResponder()
        #expect(abs((cardTop(in: tv) ?? 0) - (editing ?? 0)) <= tolerance)
    }

    @Test func aTableKeepsItsPositionAcrossFocus() {
        let rows = (1...12).map { "| Row \($0) | Value \($0) |" }
        let text = (["Prose above.", "", "| Item | Estimate |", "| --- | --- |"] + rows)
            .joined(separator: "\n")
        let (co, tv, page, _) = page(text)

        _ = tv.becomeFirstResponder()
        tv.selectedRange = NSRange(location: 0, length: 0)
        co.restyle(tv)
        let editing = tableCardTop(in: tv)

        _ = page.header.titleField.becomeFirstResponder()
        let reading = tableCardTop(in: tv)

        #expect(editing != nil && reading != nil)
        #expect(abs((reading ?? 0) - (editing ?? 0)) <= tolerance,
                "the table moved \((reading ?? 0) - (editing ?? 0))pt when the title took focus")
    }

    // MARK: The reservation is the size it says it is

    /// The reserved region must equal the card that goes into it — at every block length. The error
    /// this closes was ~1.7pt *per line*, so it only looked like rounding on a short block.
    @Test(arguments: [4, 8, 16, 32, 100])
    func theReservedRegionMatchesTheCard(lines: Int) {
        let text = codeNote(lines: lines)
        let (_, tv, page, _) = page(text)
        _ = page.header.titleField.becomeFirstResponder()

        let block = CodeBlock.blocks(in: text)[0]
        let intended = CodeCardLayout.layout(for: block,
                                             availableWidth: tv.textContainer.size.width)!.reservedHeight
        let actual = span(ofLines: block.lineRange, in: tv)
        #expect(abs(actual - intended) <= tolerance,
                "\(lines) lines: reserved \(actual)pt for a \(intended)pt card")
    }

    /// …and the error must not accumulate: whatever it is at four lines, it is still that at a hundred.
    @Test func theReservationErrorDoesNotGrowWithLineCount() {
        var errors: [CGFloat] = []
        for lines in [4, 8, 16, 32, 100] {
            let text = codeNote(lines: lines)
            let (_, tv, page, _) = page(text)
            _ = page.header.titleField.becomeFirstResponder()
            let block = CodeBlock.blocks(in: text)[0]
            let intended = CodeCardLayout.layout(
                for: block, availableWidth: tv.textContainer.size.width)!.reservedHeight
            errors.append(abs(span(ofLines: block.lineRange, in: tv) - intended))
        }
        #expect((errors.max() ?? 0) <= tolerance, "reservation error by length: \(errors)")
    }
}
