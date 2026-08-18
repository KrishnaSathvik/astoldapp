import Foundation
import Testing
@testable import Yourly

// Structural operations described as the single minimal text edit they perform, so the editor can apply
// them through the text view's own edit primitive and the undo manager records exactly one step per user
// action (RULES.md §4: one user action = one undo action).

struct TextEditTests {
    @Test func applyingAnEditProducesTheNewTextAndCaret() {
        let edit = TextEdit(range: NSRange(location: 0, length: 0), string: "# ", selection: NSRange(location: 2, length: 0))
        let result = edit.applied(to: "hello")
        #expect(result.text == "# hello")
        #expect(result.selection == NSRange(location: 2, length: 0))
    }
}

struct TextEditInverseTests {
    // Every structural edit must be undoable to exactly the text that was there before, so each one can
    // describe its own inverse.

    @Test func inverseOfAnInsertionRemovesWhatWasInserted() {
        let text = "- Milk"
        let edit = TextEdit(range: NSRange(location: 6, length: 0), string: "\n- ", selection: NSRange(location: 9, length: 0))
        let inverse = edit.inverse(in: text, caret: NSRange(location: 6, length: 0))
        #expect(inverse == TextEdit(range: NSRange(location: 6, length: 3),
                                    string: "",
                                    selection: NSRange(location: 6, length: 0)))
        #expect(inverse.applied(to: edit.applied(to: text).text).text == text)
    }

    @Test func inverseOfAReplacementPutsTheOldMarkerBack() {
        let text = "- [ ] Task"
        let edit = TextEdit(range: NSRange(location: 0, length: 6), string: "- [x] ", selection: NSRange(location: 6, length: 0))
        let inverse = edit.inverse(in: text, caret: NSRange(location: 6, length: 0))
        #expect(inverse.string == "- [ ] ")
        #expect(inverse.applied(to: edit.applied(to: text).text).text == text)
    }

    @Test func inverseOfADeletionRestoresTheMarker() {
        let text = "# Heading"
        let edit = TextEdit(range: NSRange(location: 0, length: 2), string: "", selection: NSRange(location: 0, length: 0))
        let inverse = edit.inverse(in: text, caret: NSRange(location: 2, length: 0))
        #expect(inverse == TextEdit(range: NSRange(location: 0, length: 0),
                                    string: "# ",
                                    selection: NSRange(location: 2, length: 0)))
        #expect(inverse.applied(to: edit.applied(to: text).text).text == text)
    }
}

struct TextEditDiffTests {
    // A programmatic body change (a voice transcript landing at the caret) is a document mutation too, so
    // it is applied as one minimal native edit rather than by replacing the whole string.

    @Test func appendedTextIsASingleInsertion() {
        let edit = TextEdit.diff(from: "Intro.", to: "Intro. Hello.", caret: NSRange(location: 13, length: 0))
        #expect(edit.range == NSRange(location: 6, length: 0))
        #expect(edit.string == " Hello.")
        #expect(edit.selection == NSRange(location: 13, length: 0))
    }

    @Test func insertionInTheMiddleTouchesOnlyTheMiddle() {
        let edit = TextEdit.diff(from: "ab", to: "aXb", caret: NSRange(location: 2, length: 0))
        #expect(edit.range == NSRange(location: 1, length: 0))
        #expect(edit.string == "X")
    }

    @Test func aChangedMarkerIsASingleReplacement() {
        let edit = TextEdit.diff(from: "- a", to: "# a", caret: NSRange(location: 2, length: 0))
        #expect(edit.range == NSRange(location: 0, length: 1))
        #expect(edit.string == "#")
    }

    @Test func deletionIsASingleRemoval() {
        let edit = TextEdit.diff(from: "hello world", to: "hello", caret: NSRange(location: 5, length: 0))
        #expect(edit.range == NSRange(location: 5, length: 6))
        #expect(edit.string == "")
    }

    @Test func identicalTextIsANoOpEdit() {
        let edit = TextEdit.diff(from: "same", to: "same", caret: NSRange(location: 4, length: 0))
        #expect(edit.string == "")
        #expect(edit.range.length == 0)
        #expect(edit.applied(to: "same").text == "same")
    }

    @Test func multibyteInsertionUsesUTF16Offsets() {
        let edit = TextEdit.diff(from: "- నమస్తే", to: "- నమస్తే!", caret: NSRange(location: 10, length: 0))
        #expect(edit.string == "!")
        #expect(edit.applied(to: "- నమస్తే").text == "- నమస్తే!")
    }

    @Test func neverSplitsASurrogatePair() {
        // "👍" and "👎" share a high surrogate — trimming the common prefix naively would cut the pair
        // in half and corrupt the text storage.
        let edit = TextEdit.diff(from: "👍", to: "👎", caret: NSRange(location: 2, length: 0))
        #expect(edit.range == NSRange(location: 0, length: 2))
        #expect(edit.string == "👎")
        #expect(edit.applied(to: "👍").text == "👎")
    }

    @Test func neverSplitsACombiningSequence() {
        // "e" + U+0301 is one character; the shared "e" is not a boundary in the new text.
        let combined = "e\u{301}"
        let edit = TextEdit.diff(from: "e", to: combined, caret: NSRange(location: 2, length: 0))
        #expect(edit.range == NSRange(location: 0, length: 1))
        #expect(edit.string == combined)
        #expect(edit.applied(to: "e").text == combined)
    }

    @Test func anyDiffReconstructsTheTargetText() {
        let pairs = [("", "# A"), ("# A", ""), ("a\nb", "a\n- b"), ("- [ ] x", "- [x] x"), ("abc", "abc def")]
        for (old, new) in pairs {
            #expect(TextEdit.diff(from: old, to: new, caret: NSRange(location: 0, length: 0)).applied(to: old).text == new)
        }
    }
}

struct DocumentActionEditTests {
    @Test func returnInAListInsertsOnlyTheLineBreakAndMarker() {
        let edit = DocumentAction.returnEdit(text: "- Milk", selection: NSRange(location: 6, length: 0))
        #expect(edit == TextEdit(range: NSRange(location: 6, length: 0),
                                 string: "\n- ",
                                 selection: NSRange(location: 9, length: 0)))
    }

    @Test func returnOnAnEmptyItemRemovesOnlyThatMarker() {
        let edit = DocumentAction.returnEdit(text: "- Milk\n- ", selection: NSRange(location: 9, length: 0))
        #expect(edit == TextEdit(range: NSRange(location: 7, length: 2),
                                 string: "",
                                 selection: NSRange(location: 7, length: 0)))
    }

    @Test func returnInAParagraphIsNotOurEdit() {
        #expect(DocumentAction.returnEdit(text: "hello", selection: NSRange(location: 5, length: 0)) == nil)
    }

    @Test func backspaceRemovesOnlyTheMarker() {
        let edit = DocumentAction.backspaceEdit(text: "# Hi", selection: NSRange(location: 2, length: 0))
        #expect(edit == TextEdit(range: NSRange(location: 0, length: 2),
                                 string: "",
                                 selection: NSRange(location: 0, length: 0)))
    }

    @Test func togglingAChecklistReplacesOnlyTheBox() {
        let edit = DocumentAction.toggleChecklistEdit(text: "- [ ] Task", sourceOffset: 6)
        #expect(edit == TextEdit(range: NSRange(location: 0, length: 6),
                                 string: "- [x] ",
                                 selection: NSRange(location: 6, length: 0)))
    }

    @Test func settingABlockKindReplacesOnlyTheMarker() {
        let edit = DocumentAction.setBlockKindEdit(.heading, text: "- hello", selection: NSRange(location: 2, length: 0))
        #expect(edit == TextEdit(range: NSRange(location: 0, length: 2),
                                 string: "# ",
                                 selection: NSRange(location: 2, length: 0)))
    }
}

struct DocumentActionEditEquivalenceTests {
    // The whole-text operations (used by voice, which builds text non-interactively) and the edits the
    // editor applies MUST stay the same operation.

    @Test func returnMatchesTheWholeTextOperation() {
        let text = "- Milk"
        let selection = NSRange(location: 6, length: 0)
        let viaEdit = DocumentAction.returnEdit(text: text, selection: selection)?.applied(to: text)
        let whole = DocumentAction.handleReturn(text: text, selection: selection)
        #expect(viaEdit?.text == whole?.text)
        #expect(viaEdit?.selection == whole?.selection)
    }

    @Test func backspaceMatchesTheWholeTextOperation() {
        let text = "- [x] Task"
        let selection = NSRange(location: 6, length: 0)
        let viaEdit = DocumentAction.backspaceEdit(text: text, selection: selection)?.applied(to: text)
        let whole = DocumentAction.handleBackspace(text: text, selection: selection)
        #expect(viaEdit?.text == whole?.text)
        #expect(viaEdit?.selection == whole?.selection)
    }

    @Test func setBlockKindMatchesTheWholeTextOperation() {
        let text = "1. one"
        let selection = NSRange(location: 4, length: 0)
        let viaEdit = DocumentAction.setBlockKindEdit(.checklist(checked: false), text: text, selection: selection).applied(to: text)
        let whole = DocumentAction.setBlockKind(.checklist(checked: false), text: text, selection: selection)
        #expect(viaEdit.text == whole.text)
        #expect(viaEdit.selection == whole.selection)
    }
}
