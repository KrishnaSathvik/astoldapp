import Foundation
import Testing
@testable import Yourly

// Copy / cut / paste for the structured editor: the hidden markers ("# ", "- ", "- [ ] ") MUST NEVER
// leave the app. Other apps receive the text the reader actually sees ("• Eggs", "☐ Call Ravi"), while
// As Told keeps a private representation so structure survives an internal copy/paste.
// See docs/02-features.md (Milestone A) and RULES.md §1.

struct StructuredTextExportPlainTextTests {
    @Test func replacesHiddenMarkersWithVisibleGlyphs() {
        let source = "# Shopping\n- Eggs\n- [ ] Call Ravi"
        #expect(StructuredTextExport.plainText(source) == "Shopping\n• Eggs\n☐ Call Ravi")
    }

    @Test func checkedItemUsesATickedBox() {
        #expect(StructuredTextExport.plainText("- [x] Done") == "☑ Done")
    }

    @Test func subheadingLosesItsMarkerLikeAHeading() {
        #expect(StructuredTextExport.plainText("## Later") == "Later")
    }

    @Test func numberedListKeepsItsOrdinals() {
        #expect(StructuredTextExport.plainText("1. one\n2. two") == "1. one\n2. two")
    }

    @Test func plainNoteIsUnchanged() {
        #expect(StructuredTextExport.plainText("just text\nmore text") == "just text\nmore text")
    }

    @Test func blankLinesSurvive() {
        #expect(StructuredTextExport.plainText("- a\n\n- b") == "• a\n\n• b")
    }

    @Test func multibyteContentIsPreserved() {
        #expect(StructuredTextExport.plainText("- నమస్తే") == "• నమస్తే")
    }

    @Test func partialLineSelectionCarriesNoMarker() {
        // "- Eggs and milk": selecting only "and milk" is a fragment, not a list item.
        let source = "- Eggs and milk"
        let range = NSRange(location: 7, length: 8)
        #expect(StructuredTextExport.plainText(from: source, range: range) == "and milk")
    }

    @Test func selectionFromContentStartCarriesItsMarker() {
        let source = "- Eggs"
        let range = NSRange(location: 2, length: 4)   // "Eggs" — the whole visible line
        #expect(StructuredTextExport.plainText(from: source, range: range) == "• Eggs")
    }

    @Test func laterLinesOfASelectionKeepTheirMarkers() {
        let source = "Note\n- Eggs\n- [x] Done"
        let range = NSRange(location: 2, length: (source as NSString).length - 2)  // from "te"
        #expect(StructuredTextExport.plainText(from: source, range: range) == "te\n• Eggs\n☑ Done")
    }
}

struct StructuredTextExportCopyRangeTests {
    @Test func expandsToIncludeTheMarkerOfTheFirstSelectedLine() {
        let range = StructuredTextExport.copyRange(in: "- Eggs", selection: NSRange(location: 2, length: 4))
        #expect(range == NSRange(location: 0, length: 6))
    }

    @Test func leavesAMidLineSelectionAlone() {
        let range = StructuredTextExport.copyRange(in: "- Eggs", selection: NSRange(location: 3, length: 3))
        #expect(range == NSRange(location: 3, length: 3))
    }

    @Test func leavesAnEmptySelectionAlone() {
        let range = StructuredTextExport.copyRange(in: "- Eggs", selection: NSRange(location: 2, length: 0))
        #expect(range == NSRange(location: 2, length: 0))
    }

    @Test func leavesAPlainParagraphAlone() {
        let range = StructuredTextExport.copyRange(in: "hello", selection: NSRange(location: 0, length: 5))
        #expect(range == NSRange(location: 0, length: 5))
    }
}

struct StructuredTextExportStructuredTests {
    @Test func privateRepresentationKeepsTheRawMarkers() {
        let source = "# Shopping\n- Eggs"
        let all = NSRange(location: 0, length: (source as NSString).length)
        #expect(StructuredTextExport.structuredText(from: source, range: all) == "# Shopping\n- Eggs")
    }

    @Test func privateRepresentationIsNilWhenNothingIsStructured() {
        // A plain-text selection needs no second representation — the plain text already says everything.
        let source = "just text"
        let all = NSRange(location: 0, length: (source as NSString).length)
        #expect(StructuredTextExport.structuredText(from: source, range: all) == nil)
    }
}

struct DocumentActionPasteStructuredTests {
    @Test func pasteIntoAnEmptyNoteKeepsStructure() {
        let r = DocumentAction.pasteStructured("# A\n- B", text: "", selection: NSRange(location: 0, length: 0))
        #expect(r.text == "# A\n- B")
        #expect(r.selection == NSRange(location: 7, length: 0))
    }

    @Test func pasteIntoAnEmptyListItemReplacesThatItemsMarker() {
        // Caret sits in a fresh "- " bullet; pasting a heading must not leave "- # A" behind.
        let r = DocumentAction.pasteStructured("# A\n- B", text: "- ", selection: NSRange(location: 2, length: 0))
        #expect(r.text == "# A\n- B")
        #expect(r.selection == NSRange(location: 7, length: 0))
    }

    @Test func pasteIntoTextDropsTheFirstPastedMarkerSoNoMarkerBecomesVisible() {
        // Mid-content there is no line to restructure — the first pasted line joins as words.
        let r = DocumentAction.pasteStructured("# Shopping\n- Eggs", text: "Buy ", selection: NSRange(location: 4, length: 0))
        #expect(r.text == "Buy Shopping\n- Eggs")
        #expect(r.selection == NSRange(location: 19, length: 0))
    }

    @Test func pasteOverAWholeLineTakesThePastedStructure() {
        // The selection covers everything the line held, so the pasted structure wins outright.
        let r = DocumentAction.pasteStructured("# B", text: "- old", selection: NSRange(location: 2, length: 3))
        #expect(r.text == "# B")
        #expect(r.selection == NSRange(location: 3, length: 0))
    }

    @Test func pasteOverPartOfALineKeepsTheLinesOwnStructure() {
        let r = DocumentAction.pasteStructured("# B", text: "- old text", selection: NSRange(location: 2, length: 3))
        #expect(r.text == "- B text")
        #expect(r.selection == NSRange(location: 3, length: 0))
    }

    @Test func pastingPlainTextIsAnOrdinaryInsertion() {
        let r = DocumentAction.pasteStructured("world", text: "hello ", selection: NSRange(location: 6, length: 0))
        #expect(r.text == "hello world")
        #expect(r.selection == NSRange(location: 11, length: 0))
    }
}

struct DocumentActionPasteEditTests {
    // The view applies a paste as one native edit (so undo and the keyboard stay honest); these are the
    // range it replaces and the string it puts there.

    @Test func pasteIntoAnEmptyListItemReplacesTheWholeItem() {
        let edit = DocumentAction.pasteEdit("# A\n- B", text: "- ", selection: NSRange(location: 2, length: 0))
        #expect(edit.range == NSRange(location: 0, length: 2))
        #expect(edit.string == "# A\n- B")
        #expect(edit.selection == NSRange(location: 7, length: 0))
    }

    @Test func pasteMidLineReplacesOnlyTheSelection() {
        let edit = DocumentAction.pasteEdit("# Shopping", text: "Buy ", selection: NSRange(location: 4, length: 0))
        #expect(edit.range == NSRange(location: 4, length: 0))
        #expect(edit.string == "Shopping")
    }

    @Test func plainPasteIsAnUntouchedInsertion() {
        let edit = DocumentAction.pasteEdit("world", text: "hello ", selection: NSRange(location: 6, length: 0))
        #expect(edit.range == NSRange(location: 6, length: 0))
        #expect(edit.string == "world")
    }
}
