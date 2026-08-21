import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Yourly

// Undo for structural editing. Structure is one of the most visible things the editor does, so every
// structural operation MUST be a normal, undoable text edit: one user action, one undo step, and the text
// that comes back MUST be exactly what was there before (RULES.md §4).

@MainActor
struct StructuredEditorUndoTests {
    /// A live text view wired to a real coordinator, standing in for the editor.
    @MainActor
    final class Harness {
        /// Backing store for the SwiftUI bindings the editor writes through.
        final class Box {
            var text = ""
            var selection = NSRange(location: 0, length: 0)
            var isFocused = false
        }

        let box = Box()
        let textView: StructuredTextView
        let coordinator: BodyTextView.Coordinator
        private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))

        init(_ initial: String, caret: Int? = nil) {
            let box = box
            let target = NSRange(location: caret ?? (initial as NSString).length, length: 0)
            box.text = initial
            box.selection = target

            let view = BodyTextView(
                text: Binding(get: { box.text }, set: { box.text = $0 }),
                selectedRange: Binding(get: { box.selection }, set: { box.selection = $0 }),
                isFocused: Binding(get: { box.isFocused }, set: { box.isFocused = $0 }),
                isEditable: true,
                keyboardAppearance: .light
            )
            coordinator = view.makeCoordinator()
            textView = StructuredTextView.make()
            textView.delegate = coordinator
            textView.isEditable = true
            textView.frame = window.bounds
            window.addSubview(textView)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            textView.text = initial
            textView.becomeFirstResponder()
            // Set the caret only once the view is first responder — UIKit resets the selection when it
            // takes focus, and that reset travels back through the binding.
            textView.selectedRange = target
            box.selection = target
            // Only edits made *after* setup are the user's; the initial content is the starting point.
            textView.undoManager?.removeAllActions()
        }

        /// Types as the keyboard does: ask the delegate first, and fall back to the view's own insertion
        /// when it declines to handle the change (programmatic `insertText` alone skips the delegate).
        func type(_ string: String) {
            let range = textView.selectedRange
            if coordinator.textView(textView, shouldChangeTextIn: range, replacementText: string) {
                textView.insertText(string)
            }
        }

        func backspace() {
            let range = textView.selectedRange
            if coordinator.textView(textView, shouldChangeTextIn: range, replacementText: "") {
                textView.deleteBackward()
            }
        }

        var source: String { textView.text }
        var canUndo: Bool { textView.undoManager?.canUndo ?? false }
        func undo() { textView.undoManager?.undo() }
        func redo() { textView.undoManager?.redo() }
    }

    @Test func togglingAChecklistItemUndoesInOneStep() {
        let harness = Harness("- [ ] Call Ravi")
        let edit = DocumentAction.toggleChecklistEdit(text: harness.source, sourceOffset: 0)
        #expect(edit != nil)
        harness.coordinator.apply(edit!, to: harness.textView, caret: harness.textView.selectedRange)
        #expect(harness.source == "- [x] Call Ravi")

        #expect(harness.canUndo)
        harness.undo()
        #expect(harness.source == "- [ ] Call Ravi")
    }

    @Test func continuingAListUndoesInOneStep() {
        let harness = Harness("- Milk")
        let edit = DocumentAction.returnEdit(text: harness.source, selection: harness.textView.selectedRange)
        #expect(edit != nil)
        harness.coordinator.apply(edit!, to: harness.textView)
        #expect(harness.source == "- Milk\n- ")

        harness.undo()
        #expect(harness.source == "- Milk")
    }

    @Test func demotingWithBackspaceUndoesInOneStep() {
        let harness = Harness("# Heading", caret: 2)
        let edit = DocumentAction.backspaceEdit(text: harness.source, selection: harness.textView.selectedRange)
        #expect(edit != nil)
        harness.coordinator.apply(edit!, to: harness.textView)
        #expect(harness.source == "Heading")

        harness.undo()
        #expect(harness.source == "# Heading")
    }

    @Test func undoRestoresTheStructureStylingAndACaretOutsideTheMarker() {
        let harness = Harness("# Heading", caret: 2)
        let edit = DocumentAction.backspaceEdit(text: harness.source, selection: harness.textView.selectedRange)
        harness.coordinator.apply(edit!, to: harness.textView)
        harness.undo()

        // The restored marker is hidden again, and the caret is never left inside it.
        let markerIsHidden = harness.textView.textStorage
            .attribute(.astHiddenMarker, at: 0, effectiveRange: nil) != nil
        #expect(markerIsHidden)
        let line = MarkupDocument(harness.source).line(containingSource: harness.textView.selectedRange.location)
        let caret = harness.textView.selectedRange.location
        #expect(caret <= line.sourceRange.location || caret >= line.contentStart)
    }

    // The tests above drive the shared operations directly; these two go through the real typing path —
    // the text view's own insert/delete, the delegate, and the structural handling behind them.

    @Test func typingReturnInsideAListIsExactlyOneUndoStep() {
        let harness = Harness("- Milk")
        harness.type("\n")
        #expect(harness.source == "- Milk\n- ")

        harness.undo()
        #expect(harness.source == "- Milk")
        #expect(!harness.canUndo, "continuing a list must not leave a second undo step behind")
    }

    @Test func backspacingAMarkerAwayIsExactlyOneUndoStep() {
        let harness = Harness("# Heading", caret: 2)
        harness.backspace()
        #expect(harness.source == "Heading")

        harness.undo()
        #expect(harness.source == "# Heading")
        #expect(!harness.canUndo, "demoting a heading must not leave a second undo step behind")
    }

    @Test func redoReappliesTheStructuralEdit() {
        let harness = Harness("- [ ] Call Ravi")
        let edit = DocumentAction.toggleChecklistEdit(text: harness.source, sourceOffset: 0)!
        harness.coordinator.apply(edit, to: harness.textView, caret: harness.textView.selectedRange)
        harness.undo()
        #expect(harness.source == "- [ ] Call Ravi")

        harness.redo()
        #expect(harness.source == "- [x] Call Ravi")
    }

    @Test func aVoiceTranscriptUndoesInOneStep() {
        let harness = Harness("Intro.")
        harness.coordinator.applyExternalChange("Intro. New words.",
                                                caret: NSRange(location: 17, length: 0),
                                                to: harness.textView)
        #expect(harness.source == "Intro. New words.")

        harness.undo()
        #expect(harness.source == "Intro.")
    }
}

/// The claim the Cmd-Z UI test makes, asserted where no keystroke has to be delivered to make it.
///
/// `testUndoingAMultiLineConversionTakesOneStep` drives undo through XCUITest's `typeKey`, whose HID
/// delivery this project has repeatedly measured as unreliable — so when it goes red it cannot tell a
/// broken editor from a dropped keystroke. This suite settles the product half of that question: the
/// toolbar's own action, one undo, exactly the text that was there before.
@MainActor
struct MultiLineConversionUndoTests {

    private func converted(to style: BlockStyle) -> StructuredEditorUndoTests.Harness {
        let harness = StructuredEditorUndoTests.Harness("Milk\nEggs\nBread", caret: 0)
        harness.textView.selectedRange = NSRange(location: 0, length: (harness.source as NSString).length)
        let actions = BodyEditorActions()
        harness.coordinator.bind(actions, to: harness.textView)
        actions.apply(style)
        return harness
    }

    @Test(arguments: [BlockStyle.bullet, .numbered, .checklist])
    func oneTapOnTheToolbarIsExactlyOneUndoStep(style: BlockStyle) {
        let harness = converted(to: style)
        #expect(harness.source != "Milk\nEggs\nBread", "the conversion did not happen")

        harness.undo()

        #expect(harness.source == "Milk\nEggs\nBread",
                "one undo did not restore all three lines")
        #expect(harness.canUndo == false, "the conversion left more than one step on the stack")
    }

    @Test func redoPutsTheConversionBack() {
        let harness = converted(to: .bullet)
        let converted = harness.source
        harness.undo()
        harness.redo()
        #expect(harness.source == converted)
    }

    @Test func theWholeSelectionSurvivesTheConversion() {
        let harness = converted(to: .bullet)
        #expect(harness.source == "- Milk\n- Eggs\n- Bread")
        #expect(harness.textView.selectedRange.length > 0,
                "a writer who picked the wrong style has to be able to pick another without reselecting")
    }
}
