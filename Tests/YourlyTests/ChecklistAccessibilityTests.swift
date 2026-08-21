import Foundation
import Testing
import UIKit
@testable import Yourly

// Operating a checklist without touching it.
//
// VoiceOver could already *hear* a checklist — `StructuredTextExport.spokenText` reads "Unchecked,
// Call Ravi" rather than the box glyph or the stored `- [ ] ` — but hearing a control is not access
// to it. The only way to tick an item was a touch inside its gutter band, and a rotor cannot aim a
// touch. Each item now carries an accessibility action of its own, and that action makes the *same*
// edit the touch does (RULES.md §4, docs/03-design-system.md).

@MainActor
struct ChecklistAccessibilityTests {
    private typealias Harness = StructuredEditorUndoTests.Harness

    private func actions(_ harness: Harness) -> [UIAccessibilityCustomAction] {
        harness.textView.accessibilityCustomActions ?? []
    }

    private func activate(_ action: UIAccessibilityCustomAction) -> Bool {
        action.actionHandler?(action) ?? false
    }

    @Test func everyChecklistItemOffersAnActionOfItsOwn() {
        let harness = Harness("- [ ] Call Ravi\n- [x] Book hotel\n- [ ] Pack")
        #expect(actions(harness).map(\.name) == ["Check Call Ravi", "Uncheck Book hotel", "Check Pack"])
    }

    /// The action is named with what the reader sees. The canonical syntax is storage, and storage is
    /// never spoken — not in the value, and not here either.
    @Test func theActionNamesNeverSpeakTheStoredMarkers() {
        let harness = Harness("- [ ] Call Ravi\n- [x] Book hotel")
        for name in actions(harness).map(\.name) {
            #expect(!name.contains("- ["), "an action was named \(name)")
            #expect(!name.contains("[ ]") && !name.contains("[x]"), "an action was named \(name)")
        }
    }

    /// The item that was chosen is the item that changes, with several to choose between.
    @Test func anActionTicksItsOwnItemAndNoOther() {
        let harness = Harness("- [ ] Call Ravi\n- [ ] Book hotel\n- [ ] Pack")
        #expect(activate(actions(harness)[1]))
        #expect(harness.source == "- [ ] Call Ravi\n- [x] Book hotel\n- [ ] Pack")
    }

    /// The same hard case, through VoiceOver: the middle of three, which has a neighbour on both
    /// sides to get wrong. The item chosen is the item that changes — and *nothing* else does, not the
    /// items either side of it, not their own actions, and not the caret.
    @Test func togglingTheMiddleItemLeavesBothNeighboursAlone() {
        let harness = Harness("- [ ] One\n- [ ] Two\n- [ ] Three", caret: 8)
        let caret = harness.textView.selectedRange
        #expect(activate(actions(harness)[1]))

        #expect(harness.source == "- [ ] One\n- [x] Two\n- [ ] Three")
        #expect(actions(harness).map(\.name) == ["Check One", "Uncheck Two", "Check Three"],
                "a neighbour's own action changed")
        #expect(harness.textView.accessibilityValue == "Unchecked, One\nChecked, Two\nUnchecked, Three")
        #expect(harness.textView.selectedRange == caret)

        // And back, leaving the note exactly as it started.
        #expect(activate(actions(harness)[1]))
        #expect(harness.source == "- [ ] One\n- [ ] Two\n- [ ] Three")
    }

    @Test func anActionUnticksAnItemThatIsAlreadyTicked() {
        let harness = Harness("- [ ] Call Ravi\n- [x] Book hotel")
        #expect(activate(actions(harness)[1]))
        #expect(harness.source == "- [ ] Call Ravi\n- [ ] Book hotel")
    }

    /// Unchecked → checked → unchecked, through the actions as they are re-read each time. The name
    /// follows the state, so the reader is always told what activating it will do.
    @Test func theActionFollowsTheItemsStateBothWays() {
        let harness = Harness("- [ ] Call Ravi")
        #expect(actions(harness)[0].name == "Check Call Ravi")
        #expect(activate(actions(harness)[0]))
        #expect(harness.source == "- [x] Call Ravi")

        #expect(actions(harness)[0].name == "Uncheck Call Ravi")
        #expect(activate(actions(harness)[0]))
        #expect(harness.source == "- [ ] Call Ravi")
    }

    /// A tick is not a navigation. The words do not move and neither does the insertion point — the
    /// same promise `handleTap` makes, because it is the same edit underneath.
    @Test func tickingThroughAnActionLeavesTheCaretWhereItWas() {
        let harness = Harness("- [ ] Call Ravi\n- [ ] Book hotel", caret: 10)
        let before = harness.textView.selectedRange
        #expect(activate(actions(harness)[1]))
        #expect(harness.textView.selectedRange == before)
        #expect(harness.textView.text.hasPrefix("- [ ] Call Ravi"), "the other lines are untouched")
    }

    /// One action, one undo step, exactly the text that was there before (RULES.md §4).
    @Test func tickingThroughAnActionIsOneUndoStep() {
        let harness = Harness("- [ ] Call Ravi\n- [ ] Book hotel")
        #expect(activate(actions(harness)[0]))
        #expect(harness.source == "- [x] Call Ravi\n- [ ] Book hotel")

        #expect(harness.canUndo)
        harness.undo()
        #expect(harness.source == "- [ ] Call Ravi\n- [ ] Book hotel")
        harness.redo()
        #expect(harness.source == "- [x] Call Ravi\n- [ ] Book hotel")
    }

    /// The value VoiceOver reads is derived from the note, so it is already right the moment the edit
    /// lands — no second copy of the state to fall behind.
    @Test func theSpokenValueChangesWithTheItem() {
        let harness = Harness("- [ ] Call Ravi")
        #expect(harness.textView.accessibilityValue == "Unchecked, Call Ravi")
        #expect(activate(actions(harness)[0]))
        #expect(harness.textView.accessibilityValue == "Checked, Call Ravi")
    }

    /// The action makes the same edit the gutter does. Not "an equivalent one" — the same call, so the
    /// two ways into a checkbox cannot drift apart.
    @Test func theActionAndTheGutterTapMakeTheSameEdit() {
        let byTouch = Harness("- [ ] Call Ravi\n- [ ] Book hotel")
        let edit = DocumentAction.toggleChecklistEdit(text: byTouch.source, sourceOffset: 16)
        #expect(edit != nil)
        byTouch.coordinator.apply(edit!, to: byTouch.textView, caret: byTouch.textView.selectedRange)

        let byAction = Harness("- [ ] Call Ravi\n- [ ] Book hotel")
        #expect(activate(actions(byAction)[1]))

        #expect(byTouch.source == byAction.source)
        #expect(byTouch.textView.selectedRange == byAction.textView.selectedRange)
    }

    /// Return on a checklist leaves an item holding nothing but its marker. "Check " — a verb and a
    /// silence — names nothing a reader could pick out of a rotor, so an item with no words is called
    /// what it is.
    @Test func anItemWithNoWordsIsStillNamed() {
        let harness = Harness("- [ ] Call Ravi\n- [ ] \n- [x]    ")
        #expect(actions(harness).map(\.name) == ["Check Call Ravi", "Check item", "Uncheck item"])
    }

    @Test func aNoteWithoutAChecklistOffersNoActions() {
        #expect(actions(Harness("Shopping\n- Eggs\n1. First")).isEmpty)
    }

    /// While a recording owns the anchor the body is not editable, and a tick has nowhere to be
    /// applied — so it is not offered, exactly as the gutter tap does nothing then.
    @Test func aBodyThatCannotBeEditedOffersNoActions() {
        let harness = Harness("- [ ] Call Ravi")
        harness.textView.isEditable = false
        #expect(actions(harness).isEmpty)
    }
}
