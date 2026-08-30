import Testing
import Foundation
import UIKit
import SwiftUI
@testable import Yourly

// Share sends what is on screen, not what was last saved.
//
// The bug this exists to prevent: somebody changes a table cell from `Anchorage` to `Fairbanks` and
// taps Share straight away. A cell being edited lives in the card's own text field until it commits,
// so for exactly as long as that field is open the note on screen and the note in `body` disagree —
// and the sheet would send the older word. `BodyEditorActions.commitPendingEdits()` closes the gap
// before the payload is built.
//
// Typing in the body itself has never had that gap (every keystroke reaches the binding), and there
// is a test here for that too, because "it already works" is worth a line that fails if it stops.
@MainActor
struct ShareLatestEditTests {

    private let table = "| Stop | Day |\n| --- | --- |\n| Anchorage | Mon |"

    private func editor(_ text: String) -> (BodyEditorActions, BodyTextView.Coordinator,
                                            StructuredTextView, () -> String, UIWindow) {
        var body = text
        var range = NSRange(location: 0, length: 0)
        var focused = false
        let actions = BodyEditorActions()
        let parent = BodyTextView(text: Binding(get: { body }, set: { body = $0 }),
                                  selectedRange: Binding(get: { range }, set: { range = $0 }),
                                  isFocused: Binding(get: { focused }, set: { focused = $0 }),
                                  isEditable: true,
                                  keyboardAppearance: .light,
                                  actions: actions)
        let tv = StructuredTextView.make()
        tv.frame = CGRect(x: 0, y: 0, width: 360, height: 800)
        tv.textContainer.size = CGSize(width: 360, height: 100_000)
        tv.text = text
        let coordinator = parent.makeCoordinator()
        tv.delegate = coordinator
        // A card is a real subview and a cell field is a real responder, so the text view has to be in
        // a window for either to behave — the same setup `TableCellInteractionTests` uses.
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 800))
        window.addSubview(tv)
        window.makeKeyAndVisible()
        coordinator.restyle(tv)
        coordinator.bind(actions, to: tv)
        return (actions, coordinator, tv, { body }, window)
    }

    private func card(in tv: UITextView) -> TableCardView? {
        tv.subviews.compactMap { $0 as? TableCardView }.first
    }

    // MARK: The gap that mattered

    @Test func aPendingTableCellEditIsCommittedBeforeTheNoteIsShared() {
        let (actions, co, tv, _, _) = editor(table)
        co.restyle(tv)

        // The writer opens a cell and types into it. Nothing has reached `body` yet.
        guard let card = card(in: tv) else {
            Issue.record("the table did not render as a card")
            return
        }
        _ = card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Fairbanks")
        #expect(tv.text.contains("Anchorage"), "the premise is gone: the edit already committed")

        // Share taps. The cell commits first, and the text handed back is what is on screen.
        let committed = actions.commitPendingEdits()
        #expect(committed?.contains("Fairbanks") == true, "Share would have sent the older word")
        #expect(committed?.contains("Anchorage") == false)

        let payload = NoteSharePayload.make(title: nil, body: committed ?? "")
        #expect(payload?.plainText.contains("Fairbanks") == true)
    }

    @Test func committingReturnsTheTextViewsOwnText() {
        // `co` is bound rather than discarded on purpose: the action captures the coordinator weakly,
        // so a test that lets it go measures a dead editor instead of a live one.
        let (actions, co, tv, _, _) = editor("Anchorage → Seward")
        #expect(actions.commitPendingEdits() == tv.text)
        _ = co
    }

    @Test func anOrdinaryTypedEditIsAlreadyThere() {
        // No table involved: the binding is written on every keystroke, so there is nothing to commit
        // and `commitPendingEdits` simply agrees with the screen.
        let (actions, coordinator, tv, body, _) = editor("Anchorage")
        let edit = TextEdit.diff(from: tv.text, to: "Fairbanks", caret: NSRange(location: 9, length: 0))
        _ = coordinator.apply(edit, to: tv)

        #expect(body() == "Fairbanks", "the binding did not receive the edit")
        #expect(actions.commitPendingEdits() == "Fairbanks")
        #expect(NoteSharePayload.make(title: nil, body: actions.commitPendingEdits() ?? "")?
            .plainText == "Fairbanks")
    }

    @Test func committingWithNoTextViewIsHarmless() {
        // Before `makeUIView` has run there is nothing to commit and nothing to read.
        #expect(BodyEditorActions().commitPendingEdits() == nil)
    }

    @Test func aDeadEditorAnswersNilRatherThanEmpty() {
        // The distinction that matters: `""` is a perfectly good note body, so returning it from a
        // torn-down editor would be indistinguishable from "the note is empty", and the caller would
        // share nothing rather than fall back to the model's own copy.
        let actions = BodyEditorActions()
        do {
            let (_, co, tv, _, _) = editor("Anchorage")
            co.bind(actions, to: tv)
            #expect(actions.commitPendingEdits() == "Anchorage")
        }
        // The coordinator and its text view are gone; the action outlived them.
        #expect(actions.commitPendingEdits() == nil)
    }

    @Test func committingTwiceIsStable() {
        let (actions, co, _, _, _) = editor(table)
        let first = actions.commitPendingEdits()
        let second = actions.commitPendingEdits()
        #expect(first == second)
        #expect(first?.contains("Anchorage") == true)
        _ = co
    }

    // MARK: Sharing is not an edit

    @Test func preparingToShareDoesNotChangeANoteThatHasNoPendingEdit() {
        let (actions, co, tv, body, _) = editor(table)
        defer { _ = co }
        let before = tv.text
        _ = actions.commitPendingEdits()
        #expect(tv.text == before)
        #expect(body() == before, "preparing to share rewrote the note")
    }

    @Test func aCommittedCellIsOneOrdinaryUndoableStep() {
        // Committing is the writer's own edit landing through the normal path — it would have landed on
        // the next tap anywhere else. So it undoes like any other edit, and Share has not invented a
        // change the writer cannot take back.
        let (actions, co, tv, _, _) = editor(table)
        co.restyle(tv)
        guard let card = card(in: tv) else {
            Issue.record("the table did not render as a card")
            return
        }
        _ = card.beginEditing(.init(row: 1, column: 0))
        card.setCellTextForTesting("Fairbanks")
        _ = actions.commitPendingEdits()
        #expect(tv.text.contains("Fairbanks"))

        tv.undoManager?.undo()
        #expect(tv.text.contains("Anchorage"), "the committed cell could not be undone")
    }
}
