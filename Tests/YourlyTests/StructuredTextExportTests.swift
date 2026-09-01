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

    /// A Home or search row draws the checklist the way the editor does — a circle — while the text
    /// that leaves the app keeps the box other apps recognise. Two spellings, two audiences, one source.
    @Test func previewDrawsAChecklistAsCirclesWhileExportKeepsTheBox() {
        let source = "- [ ] Reserve hotels\n- [x] Compare flights"
        #expect(StructuredTextExport.previewText(source) == "○ Reserve hotels\n✓ Compare flights")
        #expect(StructuredTextExport.plainText(source) == "☐ Reserve hotels\n☑ Compare flights")
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

// What a *reading* surface gets. A note page draws its tables (`TableCardView`); everywhere else that
// shows a note as text — a Home row, a search result, VoiceOver — was handed the canonical source, so
// `| Day | Date | Schedule |` and the `| --- |` rule under it turned up on screen and in the ear. The
// pipes are how the table is stored, and storage is not something a reader decodes (RULES.md §4).
//
// The pasteboard is deliberately *not* changed by any of this: copying a table still yields its source,
// which is the documented contract (docs/02-features.md).

private let tableNote = """
Costs so far.

| Expense | 2 people |
| --- | --- |
| 9 nights lodging | $2,400-$3,600 |
| Rental car | $1,500-$2,000 |

Still need to book.
"""

struct StructuredTextPreviewTests {

    @Test func aTableReadsAsItsCellsRatherThanItsPipes() {
        let preview = StructuredTextExport.previewText(tableNote)
        #expect(!preview.contains("|"), "the table's pipes reached a reading surface")
        #expect(!preview.contains("---"), "the delimiter row reached a reading surface")
    }

    @Test func everyCellSurvivesThePreview() {
        let preview = StructuredTextExport.previewText(tableNote)
        for cell in ["Expense", "2 people", "9 nights lodging", "$2,400-$3,600",
                     "Rental car", "$1,500-$2,000"] {
            #expect(preview.contains(cell), "\(cell) was dropped from the preview")
        }
    }

    @Test func theProseAroundATableIsUntouched() {
        let preview = StructuredTextExport.previewText(tableNote)
        #expect(preview.hasPrefix("Costs so far."))
        #expect(preview.hasSuffix("Still need to book."))
    }

    /// A preview draws the editor's circle, not the pasteboard's box (`BlockKind.previewMarker`).
    @Test func listsStillShowTheMarkersTheReaderSees() {
        #expect(StructuredTextExport.previewText("# Shopping\n- Eggs\n- [ ] Call Ravi\n- [x] Done")
                == "Shopping\n• Eggs\n○ Call Ravi\n✓ Done")
    }

    @Test func aNoteWithoutATableIsExactlyItsVisibleText() {
        let source = "# Head\n- One\n1. Two\nplain"
        #expect(StructuredTextExport.previewText(source) == StructuredTextExport.plainText(source))
    }

    /// A row of the note that merely contains a pipe is not a table and keeps its characters.
    @Test func proseHoldingAPipeKeepsIt() {
        #expect(StructuredTextExport.previewText("chicken | rice") == "chicken | rice")
    }

    /// The pasteboard keeps the source. Copying a table out is documented to yield exactly that, and
    /// this fix must not have quietly changed what leaves the app.
    @Test func copyingATableStillYieldsItsSource() {
        #expect(StructuredTextExport.plainText(tableNote).contains("| --- | --- |"))
    }
}

/// What VoiceOver is told. The value used to be the note with every marker *removed*, so a ticked and
/// an unticked box read identically and a bullet read as a paragraph — state carried by a drawn glyph
/// and nothing else, which docs/03-design-system.md forbids.
struct StructuredTextSpokenTests {

    @Test func aBulletIsAnnouncedAsOne() {
        #expect(StructuredTextExport.spokenText("- Eggs") == "Bullet, Eggs")
    }

    @Test func anUncheckedItemIsDistinguishableFromACheckedOne() {
        #expect(StructuredTextExport.spokenText("- [ ] Call Ravi") == "Unchecked, Call Ravi")
        #expect(StructuredTextExport.spokenText("- [x] Book hotel") == "Checked, Book hotel")
    }

    @Test func aNumberedItemKeepsItsOrdinal() {
        #expect(StructuredTextExport.spokenText("1. one\n2. two") == "1. one\n2. two")
    }

    @Test func proseAndHeadingsAreSpokenAsTheirWords() {
        #expect(StructuredTextExport.spokenText("# Head\n## Sub\nplain") == "Head\nSub\nplain")
    }

    @Test func noSourceMarkerIsEverSpoken() {
        let spoken = StructuredTextExport.spokenText("# Head\n- One\n1. Two\n- [ ] Three\n- [x] Four")
        for marker in ["# ", "## ", "- ", "- [ ] ", "- [x] "] {
            #expect(!spoken.contains(marker), "VoiceOver would read the source marker \(marker.debugDescription)")
        }
    }

    @Test func aTableIsSpokenAsItsCellsAndNeverItsPipes() {
        let spoken = StructuredTextExport.spokenText(tableNote)
        #expect(!spoken.contains("|"))
        #expect(!spoken.contains("---"))
        #expect(spoken.contains("9 nights lodging"))
        #expect(spoken.contains("$2,400-$3,600"))
    }
}

/// What Home and Search hand VoiceOver.
///
/// Both rows draw a note as text and both labelled themselves with `previewText` — the spelling
/// written for the eye — so a reader who could not see the page was given `☐ Call Ravi`: the state of
/// the item carried by a drawn mark and nothing else, which RULES.md §4 forbids. The glyphs stay on
/// screen; the words go to the ear.
struct SpokenRowTests {

    @Test func aChecklistIsSpokenAsItsState() {
        let row = StructuredTextExport.spokenRow(title: nil, body: "- [ ] Call Ravi\n- [x] Book hotel")
        #expect(row == "Unchecked, Call Ravi\nChecked, Book hotel")
    }

    /// The eye keeps a glyph — the circle the editor draws. Both spellings exist because both
    /// audiences do.
    @Test func theVisiblePreviewIsUnchanged() {
        let body = "- [ ] Call Ravi"
        #expect(StructuredTextExport.previewText(body) == "○ Call Ravi")
        #expect(StructuredTextExport.spokenRow(title: nil, body: body) == "Unchecked, Call Ravi")
    }

    @Test func noRowEverSpeaksAGlyphOrAMarker() {
        let row = StructuredTextExport.spokenRow(title: "Trip",
                                                 body: "# Packing\n- Socks\n1. Passport\n- [x] Charger")
        for glyph in ["☐", "☑", "•", "- [", "# "] {
            #expect(!row.contains(glyph), "a row spoke \(glyph): \(row)")
        }
    }

    @Test func theTitleLeadsWhenThereIsOne() {
        #expect(StructuredTextExport.spokenRow(title: "Trip", body: "- Socks") == "Trip. Bullet, Socks")
    }

    /// A note that is nothing but a title says the title, not "Trip. ".
    @Test func aTitleWithoutABodyStandsAlone() {
        #expect(StructuredTextExport.spokenRow(title: "Trip", body: "") == "Trip")
    }

    /// Leading blank lines go, exactly as they do on screen — otherwise a note that opens with a
    /// newline announces an empty first line before it says anything.
    @Test func leadingBlankLinesAreDropped() {
        #expect(StructuredTextExport.spokenRow(title: nil, body: "\n\n- Socks") == "Bullet, Socks")
    }

    /// The pipes never reach the ear either — the half of this that was already fixed, kept fixed.
    @Test func aTableIsSpokenAsItsCells() {
        let row = StructuredTextExport.spokenRow(title: nil, body: "| Day | Park |\n| --- | --- |\n| 1 | Kenai |")
        #expect(!row.contains("|"))
        #expect(row.contains("Kenai"))
    }
}

/// `previewLines` — the Home row's one-line spelling of a note.
///
/// A Home row is one line tall and a note is not, so the row joins these. What matters is that
/// nothing structural survives the flattening: a checklist arriving as its first item alone, or a
/// fence or a pipe reaching a row, are the two ways this goes wrong.
struct PreviewLinesTests {
    @Test func aChecklistFlattensToItsItemsAndTheirState() {
        let lines = StructuredTextExport.previewLines("- [x] Website\n- [x] Voice V2\n- [ ] Screenshots")
        #expect(lines == ["✓ Website", "✓ Voice V2", "○ Screenshots"])
        #expect(lines.joined(separator: "  ") == "✓ Website  ✓ Voice V2  ○ Screenshots")
    }

    @Test func blankLinesAreDroppedSoARowNeverStartsEmpty() {
        #expect(StructuredTextExport.previewLines("\n\n   \nFirst real words") == ["First real words"])
    }

    @Test func noMarkerOrFenceOrPipeReachesARow() {
        let note = "# Shopping\n- Eggs\n```sql\nSELECT 1\n```\n| Day | Cost |\n| --- | --- |\n| Mon | 20 |"
        let joined = StructuredTextExport.previewLines(note).joined(separator: "  ")
        for leak in ["# ", "- [", "```", "|"] {
            #expect(!joined.contains(leak), "row preview leaked \(leak) — \(joined)")
        }
        #expect(joined.contains("Shopping"))
        #expect(joined.contains("• Eggs"))
        #expect(joined.contains("SELECT 1"))
        #expect(joined.contains("Day · Cost"))
    }

    @Test func anEmptyBodyProducesNoLines() {
        #expect(StructuredTextExport.previewLines("").isEmpty)
        #expect(StructuredTextExport.previewLines("   \n  ").isEmpty)
    }
}
