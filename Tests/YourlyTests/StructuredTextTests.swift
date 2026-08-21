import Foundation
import Testing
@testable import Yourly

// Slice 1: the pure structured-text layer — parsing, source<->visible offset mapping, and the shared
// document operations. All offsets are UTF-16 (NSString) units, in source coordinates.

struct BlockKindParseTests {
    @Test func parsesHeading() {
        let (kind, len) = BlockKind.parse(line: "# Hello")
        #expect(kind == .heading)
        #expect(len == 2)
    }

    @Test func parsesSubheadingBeforeHeading() {
        let (kind, len) = BlockKind.parse(line: "## Hi")
        #expect(kind == .subheading)
        #expect(len == 3)
    }

    @Test func parsesBullet() {
        let (kind, len) = BlockKind.parse(line: "- item")
        #expect(kind == .bullet)
        #expect(len == 2)
    }

    @Test func parsesUncheckedChecklist() {
        let (kind, len) = BlockKind.parse(line: "- [ ] task")
        #expect(kind == .checklist(checked: false))
        #expect(len == 6)
    }

    @Test func parsesCheckedChecklist() {
        let (kind, len) = BlockKind.parse(line: "- [x] done")
        #expect(kind == .checklist(checked: true))
        #expect(len == 6)
    }

    @Test func parsesNumberedItemWithArbitraryOrdinal() {
        let (kind, len) = BlockKind.parse(line: "3. third")
        #expect(kind == .numbered(3))
        #expect(len == 3)
    }

    @Test func parsesMultiDigitNumbered() {
        let (kind, len) = BlockKind.parse(line: "12. twelfth")
        #expect(kind == .numbered(12))
        #expect(len == 4)
    }

    @Test func plainLineIsParagraph() {
        let (kind, len) = BlockKind.parse(line: "just text")
        #expect(kind == .paragraph)
        #expect(len == 0)
    }

    @Test func markerRequiresTrailingSpace() {
        #expect(BlockKind.parse(line: "#no space").kind == .paragraph)
        #expect(BlockKind.parse(line: "-nope").kind == .paragraph)
    }

    @Test func emptyLineIsParagraph() {
        #expect(BlockKind.parse(line: "").kind == .paragraph)
    }

    @Test func markersRoundTrip() {
        #expect(BlockKind.heading.marker == "# ")
        #expect(BlockKind.subheading.marker == "## ")
        #expect(BlockKind.bullet.marker == "- ")
        #expect(BlockKind.numbered(2).marker == "2. ")
        #expect(BlockKind.checklist(checked: false).marker == "- [ ] ")
        #expect(BlockKind.checklist(checked: true).marker == "- [x] ")
        #expect(BlockKind.paragraph.marker == "")
    }
}

struct MarkupDocumentTests {
    @Test func parsesLinesAndKinds() {
        let doc = MarkupDocument("# Title\n- a\n- b")
        #expect(doc.lines.count == 3)
        #expect(doc.lines.map(\.kind) == [.heading, .bullet, .bullet])
    }

    @Test func visibleTextStripsMarkers() {
        let doc = MarkupDocument("# Title\n- a\n- b")
        #expect(doc.visibleText() == "Title\na\nb")
    }

    @Test func plainNoteIsUnchanged() {
        let doc = MarkupDocument("just text\nmore text")
        #expect(doc.lines.map(\.kind) == [.paragraph, .paragraph])
        #expect(doc.visibleText() == "just text\nmore text")
        #expect(doc.sourceOffset(forVisible: 5) == 5)
        #expect(doc.visibleOffset(forSource: 5) == 5)
    }

    @Test func sourceOffsetSkipsMarkerToContentStart() {
        // "# Title" — visible 0 is "T", which is source 2 (after "# ").
        let doc = MarkupDocument("# Title")
        #expect(doc.sourceOffset(forVisible: 0) == 2)
    }

    @Test func visibleOffsetAtContentStartIsZero() {
        let doc = MarkupDocument("# Title")
        #expect(doc.visibleOffset(forSource: 2) == 0)
    }

    @Test func offsetMappingAcrossLines() {
        // source:  "# Title\n- a"   visible: "Title\na"
        // visible 'a' is index 6; in source it is index 10.
        let doc = MarkupDocument("# Title\n- a")
        #expect(doc.sourceOffset(forVisible: 6) == 10)
        #expect(doc.visibleOffset(forSource: 10) == 6)
    }

    @Test func sourceOffsetInsideMarkerClampsToContent() {
        // A source offset that lands inside "# " (offset 1) maps to that line's visible content start.
        let doc = MarkupDocument("# Title")
        #expect(doc.visibleOffset(forSource: 1) == 0)
    }

    @Test func mappingHandlesMultibyteContent() {
        // Telugu content after a marker must map by UTF-16 units, not bytes.
        let doc = MarkupDocument("- నమస్తే")
        #expect(doc.visibleText() == "నమస్తే")
        // visible 0 -> source 2 (after "- ")
        #expect(doc.sourceOffset(forVisible: 0) == 2)
    }
}

struct DocumentActionSetBlockKindTests {
    @Test func addsHeadingMarkerAndShiftsCaret() {
        let r = DocumentAction.setBlockKind(.heading, text: "hello", selection: NSRange(location: 0, length: 0))
        #expect(r.text == "# hello")
        #expect(r.selection == NSRange(location: 2, length: 0))
    }

    @Test func removingToParagraphStripsMarker() {
        let r = DocumentAction.setBlockKind(.paragraph, text: "# hello", selection: NSRange(location: 4, length: 0))
        #expect(r.text == "hello")
        #expect(r.selection == NSRange(location: 2, length: 0))
    }

    @Test func replacesExistingMarker() {
        let r = DocumentAction.setBlockKind(.heading, text: "- x", selection: NSRange(location: 3, length: 0))
        #expect(r.text == "# x")
    }

    @Test func appliesToCaretLineOnly() {
        // caret on the second line; first line is untouched.
        let r = DocumentAction.setBlockKind(.bullet, text: "one\ntwo", selection: NSRange(location: 5, length: 0))
        #expect(r.text == "one\n- two")
    }
}

struct DocumentActionChecklistTests {
    @Test func togglesUncheckedToChecked() {
        let r = DocumentAction.toggleChecklist(text: "- [ ] a", sourceOffset: 6)
        #expect(r?.text == "- [x] a")
    }

    @Test func togglesCheckedToUnchecked() {
        let r = DocumentAction.toggleChecklist(text: "- [x] a", sourceOffset: 0)
        #expect(r?.text == "- [ ] a")
    }

    /// The caret a toggle reports is never inside the hidden marker, even when the caller asked from
    /// the line's start. The editor's own callers pass a caret of their own, but the primitive must not
    /// hand back the one offset a caret may never occupy.
    @Test func theReportedCaretIsNeverInsideTheMarker() {
        let r = DocumentAction.toggleChecklistEdit(text: "- [ ] a", sourceOffset: 0)
        #expect(r?.selection == NSRange(location: 6, length: 0))

        let second = DocumentAction.toggleChecklistEdit(text: "- [ ] a\n- [ ] b", sourceOffset: 8)
        #expect(second?.selection == NSRange(location: 14, length: 0))
    }

    @Test func togglingNonChecklistReturnsNil() {
        #expect(DocumentAction.toggleChecklist(text: "- a", sourceOffset: 0) == nil)
        #expect(DocumentAction.toggleChecklist(text: "plain", sourceOffset: 0) == nil)
    }

    @Test func togglesChecklistOnCorrectLine() {
        let r = DocumentAction.toggleChecklist(text: "- [ ] a\n- [ ] b", sourceOffset: 10)
        #expect(r?.text == "- [ ] a\n- [x] b")
    }
}

struct DocumentActionReturnTests {
    @Test func bulletContinuesToNextItem() {
        let r = DocumentAction.handleReturn(text: "- a", selection: NSRange(location: 3, length: 0))
        #expect(r?.text == "- a\n- ")
        #expect(r?.selection == NSRange(location: 6, length: 0))
    }

    @Test func emptyBulletExitsList() {
        let r = DocumentAction.handleReturn(text: "- ", selection: NSRange(location: 2, length: 0))
        #expect(r?.text == "")
        #expect(r?.selection == NSRange(location: 0, length: 0))
    }

    @Test func numberedContinuesIncrementing() {
        let r = DocumentAction.handleReturn(text: "1. a", selection: NSRange(location: 4, length: 0))
        #expect(r?.text == "1. a\n2. ")
        #expect(r?.selection == NSRange(location: 8, length: 0))
    }

    @Test func checklistContinuesUnchecked() {
        let r = DocumentAction.handleReturn(text: "- [x] a", selection: NSRange(location: 7, length: 0))
        #expect(r?.text == "- [x] a\n- [ ] ")
    }

    @Test func emptyChecklistItemExitsList() {
        let r = DocumentAction.handleReturn(text: "- [ ] ", selection: NSRange(location: 6, length: 0))
        #expect(r?.text == "")
    }

    @Test func paragraphReturnsNil() {
        #expect(DocumentAction.handleReturn(text: "hello", selection: NSRange(location: 5, length: 0)) == nil)
    }

    @Test func headingReturnsNil() {
        // A heading does not "continue"; the default newline yields a plain paragraph next line.
        #expect(DocumentAction.handleReturn(text: "# Title", selection: NSRange(location: 7, length: 0)) == nil)
    }

    @Test func nonEmptyListReturnsNilForRangeSelection() {
        // A non-collapsed selection is a plain replacement — let the text view handle it.
        #expect(DocumentAction.handleReturn(text: "- a", selection: NSRange(location: 2, length: 1)) == nil)
    }
}

struct DocumentActionBackspaceTests {
    @Test func bulletStartDemotesToParagraph() {
        let r = DocumentAction.handleBackspace(text: "- a", selection: NSRange(location: 2, length: 0))
        #expect(r?.text == "a")
        #expect(r?.selection == NSRange(location: 0, length: 0))
    }

    @Test func headingStartDemotesToParagraph() {
        let r = DocumentAction.handleBackspace(text: "# a", selection: NSRange(location: 2, length: 0))
        #expect(r?.text == "a")
    }

    @Test func checklistStartDemotesToParagraph() {
        let r = DocumentAction.handleBackspace(text: "- [ ] a", selection: NSRange(location: 6, length: 0))
        #expect(r?.text == "a")
        #expect(r?.selection == NSRange(location: 0, length: 0))
    }

    @Test func demotesStructuredLineInMiddleOfDocument() {
        // "x\n- a": content start of the bullet line is source offset 4.
        let r = DocumentAction.handleBackspace(text: "x\n- a", selection: NSRange(location: 4, length: 0))
        #expect(r?.text == "x\na")
        #expect(r?.selection == NSRange(location: 2, length: 0))
    }

    @Test func midContentReturnsNil() {
        #expect(DocumentAction.handleBackspace(text: "- a", selection: NSRange(location: 3, length: 0)) == nil)
    }

    @Test func paragraphStartReturnsNil() {
        #expect(DocumentAction.handleBackspace(text: "hello", selection: NSRange(location: 0, length: 0)) == nil)
    }

    @Test func rangeSelectionReturnsNil() {
        #expect(DocumentAction.handleBackspace(text: "- a", selection: NSRange(location: 2, length: 1)) == nil)
    }
}

struct VoiceInsertionStructuredTests {
    @Test func insertsMidBulletPreservingStructure() {
        // Caret after "milk" in the first bullet; the transcript continues that item's content.
        let (text, cursor) = insertTranscript("shake", into: "- milk\n- eggs", at: 6)
        #expect(text == "- milk shake\n- eggs")
        #expect(cursor == 12)
    }

    @Test func insertsIntoChecklistContentNotMarker() {
        // Caret at the start of a checklist item's content (offset 6 = after "- [ ] ").
        let (text, _) = insertTranscript("buy milk", into: "- [ ] eggs", at: 6)
        #expect(text == "- [ ] buy milkeggs" || text == "- [ ] buy milk eggs")
        #expect(text.hasPrefix("- [ ] "))
    }

    @Test func appendAtEndContinuesLastLine() {
        let (text, _) = insertTranscript("and bread", into: "- milk", at: 6)
        #expect(text == "- milk and bread")
    }
}

struct EmptyDraftTests {
    @Test func plainEmptyIsDraft() {
        #expect(Note(body: "").isEmptyDraft)
        #expect(Note(body: "   \n ").isEmptyDraft)
    }

    @Test func markerOnlyLineIsDraft() {
        #expect(Note(body: "- ").isEmptyDraft)
        #expect(Note(body: "# ").isEmptyDraft)
        #expect(Note(body: "- [ ] ").isEmptyDraft)
    }

    @Test func contentIsNotDraft() {
        #expect(!Note(body: "- milk").isEmptyDraft)
        #expect(!Note(body: "# Title").isEmptyDraft)
        #expect(!Note(title: "T", body: "").isEmptyDraft)
    }
}

struct DocumentActionInsertTextTests {
    @Test func insertsAtCaret() {
        let r = DocumentAction.insertText("hi", text: "ab", selection: NSRange(location: 1, length: 0))
        #expect(r.text == "ahib")
        #expect(r.selection == NSRange(location: 3, length: 0))
    }

    @Test func replacesSelectedRange() {
        let r = DocumentAction.insertText("X", text: "abc", selection: NSRange(location: 1, length: 1))
        #expect(r.text == "aXc")
        #expect(r.selection == NSRange(location: 2, length: 0))
    }
}
