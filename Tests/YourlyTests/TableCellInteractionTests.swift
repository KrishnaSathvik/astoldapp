import Testing
import Foundation
import UIKit
import SwiftUI
@testable import Yourly

/// Item 4, the view half: a table that stays a table while its cells are edited.
@MainActor
struct TableCellGeometryTests {

    private let source = "| Base | Nights | Notes |\n| --- | --- | --- |\n| Anchorage | 3 | north |\n| Seward | 2 | south |"

    private var layout: TableCardLayout.Layout {
        TableCardLayout.layout(for: TableBlock.tables(in: source).first!, availableWidth: 360)!
    }

    @Test func everyCellHasAFrameInsideTheCard() {
        let layout = self.layout
        #expect(!layout.isPreview)
        for row in 0..<(1 + layout.rows.count) {
            for column in layout.columnWidths.indices {
                let frame = layout.cellFrame(row: row, column: column)
                #expect(frame != nil, "no frame for (\(row), \(column))")
                #expect(frame!.minX >= 0 && frame!.maxX <= layout.size.width)
                #expect(frame!.minY >= 0 && frame!.maxY <= layout.size.height + 0.5)
            }
        }
    }

    @Test func cellsDoNotOverlap() {
        let layout = self.layout
        var frames: [CGRect] = []
        for row in 0..<(1 + layout.rows.count) {
            for column in layout.columnWidths.indices {
                guard let frame = layout.cellFrame(row: row, column: column) else { continue }
                for other in frames {
                    #expect(!frame.intersects(other.insetBy(dx: 0.5, dy: 0.5)),
                            "\(frame) overlaps \(other)")
                }
                frames.append(frame)
            }
        }
    }

    @Test func aTouchInACellFindsThatCell() {
        let layout = self.layout
        for row in 0..<(1 + layout.rows.count) {
            for column in layout.columnWidths.indices {
                let frame = layout.cellFrame(row: row, column: column)!
                let hit = layout.cell(at: CGPoint(x: frame.midX, y: frame.midY))
                #expect(hit == TableBlock.CellPosition(row: row, column: column),
                        "a touch in (\(row), \(column)) resolved to \(String(describing: hit))")
            }
        }
    }

    @Test func theHeaderRowIsRowZero() {
        let layout = self.layout
        let frame = layout.cellFrame(row: 0, column: 0)!
        #expect(frame.minY == 0)
        #expect(frame.height == layout.headerHeight)
    }

    @Test func aTouchOutsideTheGridFindsNoCell() {
        let layout = self.layout
        #expect(layout.cell(at: CGPoint(x: -5, y: 10)) == nil)
        #expect(layout.cell(at: CGPoint(x: 10, y: -5)) == nil)
        #expect(layout.cell(at: CGPoint(x: 10, y: layout.size.height + 40)) == nil)
        // The inset before the first column is the card's margin, not a cell.
        #expect(layout.cell(at: CGPoint(x: 1, y: layout.headerHeight / 2)) == nil)
    }
}

/// The card driven the way a finger drives it, and the note underneath it changing as a result.
@MainActor
struct TableCellEditingFlowTests {

    private let source = "Notes\n| Base | Nights |\n| --- | --- |\n| Anchorage | 3 |\n| Seward | 2 |\nAfter"

    private func editor() -> (BodyTextView.Coordinator, StructuredTextView, UIWindow) {
        var body = source
        var range = NSRange(location: 0, length: 0)
        var focused = true
        let parent = BodyTextView(text: Binding(get: { body }, set: { body = $0 }),
                                  selectedRange: Binding(get: { range }, set: { range = $0 }),
                                  isFocused: Binding(get: { focused }, set: { focused = $0 }),
                                  isEditable: true, keyboardAppearance: .light)
        let co = parent.makeCoordinator()
        let tv = StructuredTextView.make()
        tv.delegate = co
        tv.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        tv.textContainer.size = CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude)
        tv.text = source
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        window.addSubview(tv)
        window.makeKeyAndVisible()
        return (co, tv, window)
    }

    private func card(in tv: UITextView) -> TableCardView? {
        tv.subviews.compactMap { $0 as? TableCardView }.first
    }

    @Test func theTableIsOnScreenAsAGridBeforeAnythingIsTapped() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        #expect(card(in: tv) != nil, "the table did not draw a grid")
    }

    @Test func aCellEditReachesTheNoteAsCanonicalSource() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        guard let card = card(in: tv) else { Issue.record("no card"); return }

        card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Homer")
        card.endEditing()

        #expect(tv.text == "Notes\n| Base | Nights |\n| --- | --- |\n| Homer | 3 |\n| Seward | 2 |\nAfter")
        #expect(TableBlock.tables(in: tv.text).first?.rows[1] == ["Homer", "3"])
    }

    @Test func theGridStaysAGridThroughTheEdit() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        card(in: tv)?.beginEditing(.init(row: 1, column: 0))
        card(in: tv)?.setCellTextForTesting("Homer")
        card(in: tv)?.endEditing()
        co.restyle(tv)

        #expect(card(in: tv) != nil, "the table stopped being a grid after an edit")
        // …and not one character of its source is drawn.
        let rule = StructuredText.characterRange(ofLines: 2...2, in: tv.text as NSString)!
        #expect(tv.textStorage.attribute(.astHiddenMarker, at: rule.location, effectiveRange: nil) as? Bool == true)
    }

    @Test func returnMovesToTheNextCell() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        guard let card = card(in: tv) else { Issue.record("no card"); return }

        card.beginEditing(.init(row: 0, column: 0))
        card.advanceForTesting()
        #expect(card.editingCell == .init(row: 0, column: 1))
        // …and at the end of a row it wraps to the first cell of the next.
        card.advanceForTesting()
        #expect(card.editingCell == .init(row: 1, column: 0))
    }

    @Test func editingTheLastCellAndAdvancingLeavesTheTable() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        guard let card = card(in: tv) else { Issue.record("no card"); return }

        card.beginEditing(.init(row: 2, column: 1))
        card.advanceForTesting()
        #expect(card.editingCell == nil, "advancing past the last cell stayed in the table")
    }

    @Test func aCellEditIsOneUndoStep() {
        let harness = StructuredEditorUndoTests.Harness(source, caret: 0)
        harness.coordinator.restyle(harness.textView)
        guard let card = harness.textView.subviews.compactMap({ $0 as? TableCardView }).first else {
            Issue.record("no card"); return
        }
        card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Homer")
        card.endEditing()
        #expect(harness.source.contains("| Homer | 3 |"))

        harness.undo()
        #expect(harness.source == source, "a cell edit did not undo in one step")
    }

    @Test func theProseAroundTheTableIsNeverTouched() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        card(in: tv)?.beginEditing(.init(row: 0, column: 1))
        card(in: tv)?.setCellTextForTesting("Evenings")
        card(in: tv)?.endEditing()

        let lines = tv.text.components(separatedBy: "\n")
        #expect(lines.first == "Notes")
        #expect(lines.last == "After")
        #expect(lines[2] == "| --- | --- |")
    }

    @Test func typingNothingNewCommitsNothing() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        card(in: tv)?.beginEditing(.init(row: 1, column: 0))
        card(in: tv)?.setCellTextForTesting("Anchorage")     // unchanged
        card(in: tv)?.endEditing()
        #expect(tv.text == source)
    }
}

/// The editing *lifecycle*: every way a cell edit can end, and the promise that none of them lose it.
///
/// Added 2026-08-27 with the fix for a real data-loss defect. A cell being edited lived in the card's
/// own `UITextField` until something committed it, and the only things that did were Return, Tab,
/// tapping another cell, and Share. Tapping the note's title, letting the card retire, or simply
/// leaving the note all dropped the characters on the floor while autosave persisted a `body` that had
/// never received them.
///
/// The invariant these hold down: **an open cell commits whenever its session ends.** A table has no
/// Cancel, so there is no exit that is supposed to discard.
@MainActor
struct TableCellCommitLifecycleTests {

    private let source = "Notes\n| Base | Nights |\n| --- | --- |\n| Anchorage | 3 |\n| Seward | 2 |\nAfter"

    private func editor() -> (BodyTextView.Coordinator, StructuredTextView, UIWindow) {
        var body = source
        var range = NSRange(location: 0, length: 0)
        var focused = true
        let parent = BodyTextView(text: Binding(get: { body }, set: { body = $0 }),
                                  selectedRange: Binding(get: { range }, set: { range = $0 }),
                                  isFocused: Binding(get: { focused }, set: { focused = $0 }),
                                  isEditable: true, keyboardAppearance: .light)
        let co = parent.makeCoordinator()
        let tv = StructuredTextView.make()
        tv.delegate = co
        tv.frame = CGRect(x: 0, y: 0, width: 390, height: 800)
        tv.textContainer.size = CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude)
        tv.text = source
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
        window.addSubview(tv)
        window.makeKeyAndVisible()
        return (co, tv, window)
    }

    private func card(in tv: UITextView) -> TableCardView? {
        tv.subviews.compactMap { $0 as? TableCardView }.first
    }

    /// Focus leaving the field is the path that used to lose text: tapping the title, tapping into the
    /// body, or the editor going away all resign the field, and nothing was listening.
    @Test func losingFocusCommitsTheOpenCell() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        guard let card = card(in: tv) else { Issue.record("no card"); return }

        card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Homer")
        card.textFieldDidEndEditing(UITextField())

        #expect(tv.text.contains("| Homer | 3 |"), "losing focus did not commit the cell")
    }

    /// The commit is idempotent, which is what makes it safe to call from every exit without any of
    /// them having to know whether another one already ran.
    @Test func committingTwiceCommitsOnce() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        guard let card = card(in: tv) else { Issue.record("no card"); return }

        card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Homer")

        #expect(card.commitActiveCellIfNeeded() == true, "the first commit did nothing")
        #expect(card.commitActiveCellIfNeeded() == false, "the second commit was not a no-op")
        card.endEditing()
        card.textFieldDidEndEditing(UITextField())

        #expect(tv.text == "Notes\n| Base | Nights |\n| --- | --- |\n| Homer | 3 |\n| Seward | 2 |\nAfter")
    }

    /// The overlap that made idempotence necessary: Return commits and *then* the field resigns, so a
    /// naive `textFieldDidEndEditing` would write the same text a second time.
    @Test func returnFollowedByResignationCommitsOnce() {
        let harness = StructuredEditorUndoTests.Harness(source, caret: 0)
        harness.coordinator.restyle(harness.textView)
        guard let card = harness.textView.subviews.compactMap({ $0 as? TableCardView }).first else {
            Issue.record("no card"); return
        }

        card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Homer")
        card.advanceForTesting()                       // Return: commits, then moves on
        card.textFieldDidEndEditing(UITextField())     // the resignation that follows

        #expect(harness.source.contains("| Homer | 3 |"))
        harness.undo()
        #expect(harness.source == source, "one cell edit did not undo in one step")
    }

    /// One editing session is one undoable step, whichever exit ends it. Typing five characters into a
    /// cell must not put five entries in the undo stack — the keystrokes live in the field, and only
    /// the result ever reaches `body`.
    @Test func aCellEditEndedByFocusLossIsStillOneUndoStep() {
        let harness = StructuredEditorUndoTests.Harness(source, caret: 0)
        harness.coordinator.restyle(harness.textView)
        guard let card = harness.textView.subviews.compactMap({ $0 as? TableCardView }).first else {
            Issue.record("no card"); return
        }

        card.beginEditing(.init(row: 1, column: 0))
        for text in ["F", "Fa", "Fai", "Fair", "Fairbanks"] { card.setCellTextForTesting(text) }
        card.textFieldDidEndEditing(UITextField())

        #expect(harness.source.contains("| Fairbanks | 3 |"))
        harness.undo()
        #expect(harness.source == source, "five keystrokes in one cell were more than one undo step")
    }

    /// A cell nobody changed must not manufacture an edit — an exit is not a reason to touch the note.
    @Test func anUntouchedCellCommitsNothingOnAnyExit() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        guard let card = card(in: tv) else { Issue.record("no card"); return }

        card.beginEditing(.init(row: 1, column: 0))
        #expect(card.commitActiveCellIfNeeded() == false)
        card.beginEditing(.init(row: 1, column: 0))
        card.textFieldDidEndEditing(UITextField())
        card.endEditing()

        #expect(tv.text == source, "leaving an untouched cell changed the note")
    }

    /// Tearing the card down commits. This is the path `TableCardPresenter.sync` takes when it retires
    /// a card, and it used to pass `commit: false` — which made ordinary card churn a silent way to
    /// throw away typing.
    @Test func tearingDownACardCommitsWhatWasOpenInIt() {
        let (co, tv, _) = editor()
        co.restyle(tv)
        guard let card = card(in: tv) else { Issue.record("no card"); return }

        card.beginEditing(.init(row: 2, column: 0))
        card.setCellTextForTesting("Homer")
        card.endEditing()                              // what retirement now calls

        #expect(tv.text.contains("| Homer | 2 |"), "retiring the card discarded the open cell")
    }

    /// The page-level flush is safe to call when nothing is open and safe to call twice — Share calls
    /// it, and so now does every teardown path.
    @Test func theFlushIsHarmlessWhenThereIsNothingToCommit() {
        let (co, tv, _) = editor()
        co.restyle(tv)

        let presenter = TableCardPresenter()
        presenter.commitActiveCellEdits()
        presenter.commitActiveCellEdits()

        guard let card = card(in: tv) else { Issue.record("no card"); return }
        card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Homer")
        card.endEditing()
        card.endEditing()

        #expect(tv.text == "Notes\n| Base | Nights |\n| --- | --- |\n| Homer | 3 |\n| Seward | 2 |\nAfter")
    }
}
