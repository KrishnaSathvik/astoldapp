import Foundation
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Yourly

// Rich paste: what happens when text arrives from another app.
//
// The rule under test is the one the whole app is built on — **preserve the words** (RULES.md §2).
// Structure the clipboard states outright (an <h2>, a <ul>, a checkbox) is translated into the
// structures As Told already has; structure it does *not* state is never inferred, and no character of
// text is ever corrected, reordered, or rewritten. See docs/02-features.md (Milestone A).

struct RichPasteHTMLStructureTests {

    @Test func headingsAndListsBecomeAsToldStructure() {
        let html = """
        <h2>The Best Angle Right Now</h2>
        <p>Instead of asking a broad question.</p>
        <h3>1. Starter Packs</h3>
        <ul><li>First Freelance Client Starter Kit</li><li>Remote Job Setup Pack</li></ul>
        """
        #expect(RichPasteHTML.source(from: html) == """
        ## The Best Angle Right Now
        Instead of asking a broad question.
        ## 1. Starter Packs
        - First Freelance Client Starter Kit
        - Remote Job Setup Pack
        """)
    }

    @Test func firstLevelHeadingIsAHeading() {
        #expect(RichPasteHTML.source(from: "<h1>Shopping</h1><p>text</p>") == "# Shopping\ntext")
    }

    @Test func everyDeeperHeadingIsASubheading() {
        for level in 2...6 {
            #expect(RichPasteHTML.source(from: "<h\(level)>Later</h\(level)><p>x</p>") == "## Later\nx")
        }
    }

    @Test func orderedListKeepsItsOrder() {
        let html = "<ol><li>one</li><li>two</li><li>three</li></ol>"
        #expect(RichPasteHTML.source(from: html) == "1. one\n2. two\n3. three")
    }

    @Test func orderedListHonorsItsStartingNumber() {
        #expect(RichPasteHTML.source(from: "<ol start=\"4\"><li>four</li><li>five</li></ol>")
                == "4. four\n5. five")
    }

    @Test func anEmptyItemCostsNoNumber() {
        #expect(RichPasteHTML.source(from: "<ol><li>one</li><li></li><li>two</li></ol>")
                == "1. one\n2. two")
    }

    @Test func checkboxesBecomeChecklistItems() {
        let html = """
        <ul class="contains-task-list">
        <li class="task-list-item"><input type="checkbox" checked disabled> Call Ravi</li>
        <li class="task-list-item"><input type="checkbox" disabled> Book tickets</li>
        </ul>
        """
        #expect(RichPasteHTML.source(from: html) == "- [x] Call Ravi\n- [ ] Book tickets")
    }

    @Test func checklistMarkedByClassIsAlsoRead() {
        let html = "<ul class=\"checklist\"><li class=\"checked\">done</li><li>todo</li></ul>"
        #expect(RichPasteHTML.source(from: html) == "- [x] done\n- [ ] todo")
    }

    @Test func nestedListsFlattenAndKeepEveryWord() {
        let html = "<ul><li>outer<ul><li>inner</li></ul></li><li>after</li></ul>"
        #expect(RichPasteHTML.source(from: html) == "- outer\n- inner\n- after")
    }

    @Test func aBreakIsALineBreakAndNotASecondBullet() {
        #expect(RichPasteHTML.source(from: "<h1>T</h1><ul><li>one<br>still one</li></ul>")
                == "# T\n- one\nstill one")
    }

    @Test func consecutiveParagraphsKeepTheBlankLineBetweenThem() {
        #expect(RichPasteHTML.source(from: "<h1>T</h1><p>first</p><p>second</p>")
                == "# T\nfirst\n\nsecond")
    }

    /// Amended with V2 code blocks: `<pre>` still keeps every line and every space of indentation, and
    /// now says outright that those characters are code. Before fences existed, `body` had no way to
    /// say so, and a preformatted `# comment` arrived as a heading.
    @Test func preformattedTextKeepsEveryLineAndItsIndentation() {
        let html = "<h1>Code</h1><pre>let a = 1\n    let b = 2</pre>"
        #expect(RichPasteHTML.source(from: html)
                == "# Code\n```text\nlet a = 1\n    let b = 2\n```")
    }
}

struct RichPasteHTMLFidelityTests {

    /// Bold and italic are styling As Told does not have, and lose the styling while keeping every
    /// character of their text. A **link** left this category with V2: a destination is not an
    /// appearance, and it is now structure the clipboard stated and the note keeps.
    @Test func inlineStylingIsDroppedAndItsTextKept() {
        let html = "<h1>T</h1><p>This is <strong>really</strong> <em>important</em> " +
                   "<a href=\"https://example.com\">right now</a></p>"
        #expect(RichPasteHTML.source(from: html)
                == "# T\nThis is really important [right now](https://example.com)")
    }

    @Test func wordingSpellingAndPunctuationSurviveExactly() {
        let html = "<h1>Notes</h1><p>i dont no wether its right ,but thats what he sayed</p>"
        #expect(RichPasteHTML.source(from: html) == "# Notes\ni dont no wether its right ,but thats what he sayed")
    }

    @Test func telugoAndHindiContentIsUntouched() {
        let html = "<h2>నా జాబితా</h2><ul><li>నమస్తే</li><li>मुझे याद है</li></ul>"
        #expect(RichPasteHTML.source(from: html) == "## నా జాబితా\n- నమస్తే\n- मुझे याद है")
    }

    @Test func characterReferencesBecomeTheirCharacters() {
        let html = "<h1>A &amp; B</h1><p>&ldquo;quoted&rdquo; &mdash; 5 &lt; 6 &#8212; caf&#233;</p>"
        #expect(RichPasteHTML.source(from: html) == "# A & B\n“quoted” — 5 < 6 — café")
    }

    @Test func prettyPrintedMarkupDoesNotLeakItsIndentation() {
        let html = """
        <h1>
            Title
        </h1>
        <ul>
            <li>
                one   two
            </li>
        </ul>
        """
        #expect(RichPasteHTML.source(from: html) == "# Title\n- one two")
    }

    @Test func scriptAndStyleAreNotContent() {
        let html = "<head><style>p { color: red }</style></head><h1>T</h1>" +
                   "<script>var x = 1;</script><p>body</p>"
        #expect(RichPasteHTML.source(from: html) == "# T\nbody")
    }

    @Test func commentsAreNotContent() {
        #expect(RichPasteHTML.source(from: "<h1>T</h1><!-- a note to self --><p>body</p>")
                == "# T\nbody")
    }

    @Test func htmlWithoutStructureFallsBackToPlainText() {
        #expect(RichPasteHTML.source(from: "<p>just a sentence</p><p>and another</p>") == nil)
        #expect(RichPasteHTML.source(from: "<div>The Best Angle Right Now</div>") == nil)
        #expect(RichPasteHTML.source(from: "") == nil)
    }

    @Test func aShortLineIsNeverPromotedToAHeading() {
        // The source says "paragraph", so it stays one — nothing is read from its length or its case.
        #expect(RichPasteHTML.source(from: "<h1>Real</h1><p>THE BEST ANGLE</p>")
                == "# Real\nTHE BEST ANGLE")
    }
}

/// A table stays a table. Imports canonicalize to Markdown pipe rows in `body` — ordinary text, no new
/// model — and `TableBlock` reads them back as the grid (RULES.md §7, amended 2026-08-21). This
/// replaced the row-record fallback, which kept every cell and lost the only thing a table asserts:
/// that these values belong to each other.
struct RichPasteHTMLTableTests {

    @Test func aTableKeepsItsCellsAndRowOrder() {
        let html = """
        <table><thead><tr><th>Idea</th><th>Why It Could Work</th></tr></thead>
        <tbody><tr><td>Remote Job Hunting OS</td><td>High demand</td></tr>
        <tr><td>Creator Systems Pack</td><td>Creator economy growing</td></tr></tbody></table>
        """
        #expect(RichPasteHTML.source(from: html) == """
        | Idea | Why It Could Work |
        | --- | --- |
        | Remote Job Hunting OS | High demand |
        | Creator Systems Pack | Creator economy growing |
        """)
    }

    /// A source that marked no header still gets the rule: it is what makes the block a table rather
    /// than three lines that contain pipes, and a reader treats a first row as headings anyway.
    @Test func aTableWithoutAHeaderRowStillGetsItsRule() {
        let html = "<table><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></table>"
        #expect(RichPasteHTML.source(from: html) == "| a | b |\n| --- | --- |\n| c | d |")
    }

    @Test func aTableSitsBetweenTheProseAroundIt() {
        let html = "<h2>Ideas</h2><table><tr><td>a</td></tr></table><p>after</p>"
        #expect(RichPasteHTML.source(from: html) == "## Ideas\na\n\nafter")
    }

    @Test func aSingleColumnTableIsJustItsCells() {
        let html = "<table><tr><td>Anchorage</td></tr><tr><td>Seward</td></tr></table>"
        #expect(RichPasteHTML.source(from: html) == "Anchorage\nSeward")
    }

    @Test func aCaptionIsKeptAsTheRowAboveItsTable() {
        let html = "<table><caption>Ideas worth trying</caption><tr><td>a</td><td>b</td></tr></table>"
        #expect(RichPasteHTML.source(from: html) == "| Ideas worth trying |  |\n| --- | --- |\n| a | b |")
    }

    @Test func aTableTheMarkupNeverClosedStillKeepsItsCells() {
        #expect(RichPasteHTML.source(from: "<table><tr><td>a</td><td>b</td>") == "| a | b |\n| --- | --- |")
    }

    @Test func aCellKeepsItsWordsOnOneLine() {
        let html = "<table><tr><td><p>first</p><p>second</p></td><td>b</td></tr></table>"
        #expect(RichPasteHTML.source(from: html) == "| first second | b |\n| --- | --- |")
    }

    /// The itinerary that started all this: seven columns, which stay seven columns.
    @Test func aWideTableStaysAWideTable() {
        let html = """
        <table><thead><tr><th>Day</th><th>Date</th><th>Schedule</th><th>Park</th>
        <th>Travel</th><th>Overnight</th><th>Meals</th></tr></thead>
        <tbody><tr><td>1</td><td>Sat</td><td>Arrive &amp; Settle</td><td>—</td>
        <td>20 min drive</td><td>Anchorage</td><td>Dinner out</td></tr>
        <tr><td>2</td><td>Sun</td><td>Kenai Fjords Full Day</td><td>Kenai Fjords</td>
        <td>5 hrs driving</td><td>Anchorage</td><td>Lunch on boat</td></tr></tbody></table>
        """
        let source = try! #require(RichPasteHTML.source(from: html))
        let table = try! #require(TableBlock.tables(in: source).first)
        #expect(table.width == 7)
        #expect(table.header == ["Day", "Date", "Schedule", "Park", "Travel", "Overnight", "Meals"])
        #expect(table.records.count == 2)
        #expect(table.records[1] == ["2", "Sun", "Kenai Fjords Full Day", "Kenai Fjords",
                                     "5 hrs driving", "Anchorage", "Lunch on boat"])
    }

    @Test func everyCellSurvivesWhateverFormItTakes() {
        let cells = (1...9).map { "cell\($0)" }
        let html = "<table><tr>" + cells.map { "<td>\($0)</td>" }.joined() + "</tr></table>"
        let source = RichPasteHTML.source(from: html) ?? ""
        for cell in cells { #expect(source.contains(cell), "lost \(cell)") }
    }
}

/// The shape every reader hands on, before anything is decided about how it is written down.
struct RichPasteDocumentTests {

    @Test func aDocumentWithoutStructureIsDeclined() {
        #expect(RichPasteDocument.canonicalSource([
            .line(ImportedLine(kind: .paragraph, text: "just words", startsElement: true))
        ]) == nil)
    }

    @Test func aTableAloneIsStructureEnough() {
        #expect(RichPasteDocument.canonicalSource([
            .table(ImportedTable(rows: [["a", "b"]], headerRow: nil))
        ]) == "| a | b |\n| --- | --- |")
    }

    @Test func aCheckboxGlyphIsReadOnlyWhereTheSourceStatedAList() {
        #expect(RichPasteDocument.checkbox(startingLine: "☐ Passport")?.rest == "Passport")
        #expect(RichPasteDocument.checkbox(startingLine: "☑ Hotel")?.checked == true)
        #expect(RichPasteDocument.checkbox(startingLine: "- ☐ Passport")?.rest == "Passport")
        #expect(RichPasteDocument.checkbox(startingLine: "☐") != nil)
        #expect(RichPasteDocument.checkbox(startingLine: "☐Passport") == nil)
        #expect(RichPasteDocument.checkbox(startingLine: "Passport ☐") == nil)
        #expect(RichPasteDocument.checkbox(startingLine: "★ Passport") == nil)
    }
}

/// The bug the Alaska paste turned up: a list item whose words are wrapped in a block element — which
/// is what Docs, Notion, and GitHub all write — lost its list, and sometimes lost the whole import.
struct RichPasteListItemTests {

    @Test func anItemWrappedInADivKeepsItsBullet() {
        #expect(RichPasteHTML.source(from: "<ul><li><div>Eggs</div></li><li><div>Milk</div></li></ul>")
                == "- Eggs\n- Milk")
    }

    @Test func anItemWrappedInAParagraphKeepsItsNumber() {
        #expect(RichPasteHTML.source(from: "<ol><li><p>one</p></li><li><p>two</p></li></ol>")
                == "1. one\n2. two")
    }

    @Test func anItemWrappedInASpanIsUnaffected() {
        #expect(RichPasteHTML.source(from: "<ul><li><span>Eggs</span></li></ul>") == "- Eggs")
    }

    @Test func aTaskItemWrappedInAParagraphIsStillATaskItem() {
        let html = """
        <ul class="contains-task-list">
        <li class="task-list-item"><p><input type="checkbox" checked> Call Ravi</p></li>
        <li class="task-list-item"><p><input type="checkbox"> Book tickets</p></li>
        </ul>
        """
        #expect(RichPasteHTML.source(from: html) == "- [x] Call Ravi\n- [ ] Book tickets")
    }

    @Test func aWrappedItemStillHonorsItsOwnValue() {
        #expect(RichPasteHTML.source(from: "<ol><li value=\"4\"><p>four</p></li><li><p>five</p></li></ol>")
                == "4. four\n5. five")
    }

    @Test func prettyPrintedListMarkupKeepsEveryItem() {
        let html = """
        <ul>
            <li>
                <p>Eggs</p>
            </li>
            <li>
                <p>Milk</p>
            </li>
        </ul>
        """
        #expect(RichPasteHTML.source(from: html) == "- Eggs\n- Milk")
    }

    @Test func nestedWrappedListsFlattenAndKeepEveryWord() {
        let html = "<ul><li><p>outer</p><ul><li><p>inner</p></li></ul></li><li><p>after</p></li></ul>"
        #expect(RichPasteHTML.source(from: html) == "- outer\n- inner\n- after")
    }

    @Test func aSecondParagraphInsideAnItemIsNeverASecondItem() {
        #expect(RichPasteHTML.source(from: "<ul><li><p>one</p><p>and more</p></li></ul>")
                == "- one\n\nand more")
    }

    @Test func aParagraphAfterTheListIsStillAParagraph() {
        #expect(RichPasteHTML.source(from: "<ul><li><p>Eggs</p></li></ul><p>after</p>") == "- Eggs\n\nafter")
    }
}

/// A checkbox drawn as a character, inside a list the source itself declared.
struct RichPasteCheckboxGlyphTests {

    @Test func aGlyphInsideADeclaredListBecomesATappableItem() {
        #expect(RichPasteHTML.source(from: "<ul><li>☐ Passport</li><li>☑ Hotel booked</li></ul>")
                == "- [ ] Passport\n- [x] Hotel booked")
    }

    @Test func aGlyphInOrdinaryProseIsLeftAsTheCharacterItIs() {
        #expect(RichPasteHTML.source(from: "<h1>Pack</h1><p>☐ Passport</p>") == "# Pack\n☐ Passport")
    }

    @Test func aGlyphInsideAHeadingIsLeftAlone() {
        #expect(RichPasteHTML.source(from: "<h1>☐ Pack</h1><p>x</p>") == "# ☐ Pack\nx")
    }
}

/// Markdown, and only when the pasteboard says so.
struct RichPasteMarkdownTests {

    @Test func headingsListsAndChecklistsBecomeAsToldStructure() {
        let markdown = """
        # Alaska Trip

        ## Packing

        - Jacket
        - Gloves

        - [ ] Passport
        - [x] Tickets

        1. Book hotel
        2. Rent car
        """
        #expect(RichPasteMarkdown.source(from: markdown) == """
        # Alaska Trip

        ## Packing

        - Jacket
        - Gloves

        - [ ] Passport
        - [x] Tickets

        1. Book hotel
        2. Rent car
        """)
    }

    @Test func inlineMarkupLosesItsPunctuationAndKeepsEveryWord() {
        #expect(RichPasteMarkdown.source(from: "# T\nA **bold** and *quiet* line.")
                == "# T\nA bold and quiet line.")
    }

    /// Amended with V2 links. This read `aLinkKeepsItsWordsAndNotItsAddress` while `body` had nowhere
    /// to put an address; it now has one, and dropping the destination would be losing something the
    /// clipboard stated outright.
    @Test func aLinkKeepsItsWordsAndItsAddress() {
        #expect(RichPasteMarkdown.source(from: "# T\nRead [Major Marine](https://example.com) first.")
                == "# T\nRead [Major Marine](https://example.com) first.")
    }

    @Test func anUnpairedDelimiterIsACharacterTheWriterTyped() {
        #expect(RichPasteMarkdown.source(from: "# T\n2 * 3 = 6, see file_name.txt")
                == "# T\n2 * 3 = 6, see file_name.txt")
    }

    /// Amended with V2 code blocks: the fence the writer declared now survives into `body` instead of
    /// being unwrapped into paragraphs, which is what keeps a `#` inside it a comment.
    @Test func aFencedBlockKeepsEveryLineAndItsIndentation() {
        let markdown = "# Code\n```python\ndf = df.sort_values(\"amount\")\n    total = 1\n```"
        #expect(RichPasteMarkdown.source(from: markdown)
                == "# Code\n```python\ndf = df.sort_values(\"amount\")\n    total = 1\n```")
    }

    /// A Markdown table arrives as a table and leaves as one, in the canonical spelling `TableBlock`
    /// reads: the delimiter row is rewritten to `| --- |`, and not one cell moves.
    @Test func aMarkdownTableStaysATable() {
        let markdown = "# T\n\n| Day | Park |\n| --- | ---- |\n| 2 | Kenai Fjords |"
        #expect(RichPasteMarkdown.source(from: markdown)
                == "# T\n\n| Day | Park |\n| --- | --- |\n| 2 | Kenai Fjords |")
    }

    @Test func nestedItemsFlattenAndKeepEveryWord() {
        #expect(RichPasteMarkdown.source(from: "- Clothes\n  - Jacket\n  - Socks")
                == "- Clothes\n- Jacket\n- Socks")
    }

    @Test func aThematicBreakLeavesNoTextBehind() {
        #expect(RichPasteMarkdown.source(from: "# T\n\n---\n\nafter") == "# T\n\nafter")
    }

    @Test func multilingualContentIsUntouched() {
        #expect(RichPasteMarkdown.source(from: "# ప్రయాణం\n- హైదరాబాద్ నుంచి\n- **मुंबई** तक")
                == "# ప్రయాణం\n- హైదరాబాద్ నుంచి\n- मुंबई तक")
    }

    @Test func markdownWithoutStructureIsDeclined() {
        #expect(RichPasteMarkdown.source(from: "just a sentence") == nil)
    }

    // A table is a header row *and* the delimiter row under it. A line that merely contains a pipe is
    // a line that contains a pipe — reading one as a table meant inventing the delimiter row As Told
    // then wrote into the note, which is the one thing paste must never do (RULES.md §4).

    @Test func aProseLineHoldingAPipeIsNotATable() {
        let markdown = "# T\n\nOption A | Option B\n\nThat was the choice."
        #expect(RichPasteMarkdown.source(from: markdown)
                == "# T\n\nOption A | Option B\n\nThat was the choice.")
    }

    @Test func aPipedLineWithNoDelimiterRowNeverInventsOne() {
        let source = RichPasteMarkdown.source(from: "# T\n\nOption A | Option B")
        #expect(source?.contains("---") == false, "a delimiter row the source never had was written")
    }

    /// Two of them in a row are still two lines of prose — asserted against the same two lines without
    /// the pipes, so this pins the pipe's irrelevance rather than restating how paragraphs are spaced.
    @Test func twoProseLinesHoldingPipesReadExactlyAsProse() {
        let piped = RichPasteMarkdown.source(from: "# T\n\nchicken | rice\nbeans | corn")
        let plain = RichPasteMarkdown.source(from: "# T\n\nchicken and rice\nbeans and corn")
        #expect(piped == plain?
            .replacingOccurrences(of: "chicken and rice", with: "chicken | rice")
            .replacingOccurrences(of: "beans and corn", with: "beans | corn"))
    }

    /// Nothing was traded away for the strictness: a pipe table without leading and trailing pipes is
    /// still a table, because the delimiter row still says so.
    @Test func aHeaderlessPipeTableIsStillATable() {
        let markdown = "# T\n\nDay | Park\n--- | ---\n2 | Kenai Fjords"
        #expect(RichPasteMarkdown.source(from: markdown)
                == "# T\n\n| Day | Park |\n| --- | --- |\n| 2 | Kenai Fjords |")
    }

    /// And a pipe inside a list item stays inside the list item rather than promoting it to a grid.
    @Test func aListItemHoldingAPipeIsStillAListItem() {
        #expect(RichPasteMarkdown.source(from: "- chicken | rice\n- beans") == "- chicken | rice\n- beans")
    }

    /// A clipboard whose only "structure" was a pipe states no structure at all, so it is declined and
    /// the system's own plain-text paste runs.
    @Test func aPipeAloneIsNotStructureEnough() {
        #expect(RichPasteMarkdown.source(from: "Option A | Option B") == nil)
    }
}

struct RichPasteAttributedTests {

    private func listed(_ items: [String], format: NSTextList.MarkerFormat,
                        startingAt start: Int = 1) -> NSAttributedString {
        let list = NSTextList(markerFormat: format, options: 0)
        list.startingItemNumber = start
        let style = NSMutableParagraphStyle()
        style.textLists = [list]
        let result = NSMutableAttributedString()
        for (index, item) in items.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n")) }
            result.append(NSAttributedString(string: item, attributes: [.paragraphStyle: style]))
        }
        return result
    }

    @Test func aBoxMarkerIsAChecklistRatherThanABullet() {
        let result = listed(["\t☐\tCall Ravi", "\t☑\tBook tickets"], format: .box)
        #expect(RichPasteImport.source(fromAttributed: result) == "- [ ] Call Ravi\n- [x] Book tickets")
    }

    @Test func aCheckboxGlyphSurvivesEvenUnderADiscMarker() {
        // What As Told's own copy-out looks like once another app has re-listed it.
        let result = listed(["☐ Call Ravi", "☑ Book tickets"], format: .disc)
        #expect(RichPasteImport.source(fromAttributed: result) == "- [ ] Call Ravi\n- [x] Book tickets")
    }

    @Test func anOrdinaryBulletIsStillABullet() {
        #expect(RichPasteImport.source(fromAttributed: listed(["\t•\tEggs"], format: .disc)) == "- Eggs")
    }

    @Test func aTextListBecomesBullets() {
        let attributed = listed(["\t•\tEggs", "\t•\tMilk"], format: .disc)
        #expect(RichPasteImport.source(fromAttributed: attributed) == "- Eggs\n- Milk")
    }

    @Test func anOrderedTextListBecomesANumberedList() {
        let attributed = listed(["\t1.\tone", "\t2.\ttwo"], format: .decimal)
        #expect(RichPasteImport.source(fromAttributed: attributed) == "1. one\n2. two")
    }

    @Test func anOrderedListStartsWhereItSaysItDoes() {
        let attributed = listed(["\t4.\tfour"], format: .decimal, startingAt: 4)
        #expect(RichPasteImport.source(fromAttributed: attributed) == "4. four")
    }

    @Test func markerTextWithoutATabIsStillNotDoubled() {
        let attributed = listed(["• Eggs"], format: .disc)
        #expect(RichPasteImport.source(fromAttributed: attributed) == "- Eggs")
    }

    @Test func anItemWhoseOwnWordsHoldATabKeepsThem() {
        // Everything before a marker's tab has to *be* a marker; here it is a word, so nothing is cut.
        let attributed = listed(["Monday\tgym"], format: .disc)
        #expect(RichPasteImport.source(fromAttributed: attributed) == "- Monday\tgym")
    }

    @Test func aListItemThatOpensWithADashKeepsIt() {
        // No marker text of its own: the dash is the writer's word, not the list's glyph.
        let attributed = listed(["-cost, not price"], format: .disc)
        #expect(RichPasteImport.source(fromAttributed: attributed) == "- -cost, not price")
    }

    @Test func paragraphsAroundAListAreKeptAsParagraphs() {
        let result = NSMutableAttributedString(string: "Shopping\n")
        result.append(listed(["\t•\tEggs"], format: .disc))
        #expect(RichPasteImport.source(fromAttributed: result) == "Shopping\n- Eggs")
    }

    /// The flavor as it actually arrives: RTF from a real editor, imported by the platform. The
    /// importer resolves `\listtext` itself, so the words arrive clean and the list survives as a
    /// text list — which is the only thing here that says "this line is a list item".
    @Test func realRTFDataKeepsItsList() throws {
        let rtf = #"""
        {\rtf1\ansi\ansicpg1252\cocoartf2761
        {\fonttbl\f0\fswiss\fcharset0 Helvetica;}
        {\colortbl;\red255\green255\blue255;}
        {\*\listtable{\list\listtemplateid1{\listlevel\levelnfc23\levelnfcn23\leveljc0\levelfollow0\levelstartat1\levelspace360\levelindent0{\*\levelmarker \{disc\}}{\leveltext\leveltemplateid1\'01\uc0\u8226 ;}{\levelnumbers;}\fi-360\li720\lin720}{\listname ;}\listid1}}
        {\*\listoverridetable{\listoverride\listid1\listoverridecount0\ls1}}
        \pard\tx220\tx720\pardirnatural\partightenfactor0
        \ls1\ilvl0\f0\fs24 \cf0 {\listtext	\uc0\u8226 	}Eggs\
        {\listtext	\uc0\u8226 	}Milk\
        }
        """#
        let attributed = try NSAttributedString(
            data: Data(rtf.utf8),
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        #expect(RichPasteImport.source(fromAttributed: attributed)?.hasPrefix("- Eggs\n- Milk") == true)
    }

    @Test func realRTFDataNumbersAnOrderedListOnce() throws {
        let rtf = #"""
        {\rtf1\ansi\ansicpg1252\cocoartf2761
        {\fonttbl\f0\fswiss\fcharset0 Helvetica;}
        {\colortbl;\red255\green255\blue255;}
        {\*\listtable{\list\listtemplateid1{\listlevel\levelnfc0\levelnfcn0\leveljc0\levelfollow0\levelstartat1\levelspace360\levelindent0{\*\levelmarker \{decimal\}}{\leveltext\leveltemplateid1\'02\'00. ;}{\levelnumbers\'01;}\fi-360\li720\lin720}{\listname ;}\listid2}}
        {\*\listoverridetable{\listoverride\listid2\listoverridecount0\ls1}}
        \pard\tx220\tx720\pardirnatural\partightenfactor0
        \ls1\ilvl0\f0\fs24 \cf0 {\listtext	1.	}one\
        {\listtext	2.	}two\
        {\listtext	3.	}three\
        }
        """#
        let attributed = try NSAttributedString(
            data: Data(rtf.utf8),
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
        #expect(RichPasteImport.source(fromAttributed: attributed)?.hasPrefix("1. one\n2. two\n3. three") == true)
    }

    @Test func richTextWithoutListsFallsBackToPlainText() {
        let big = NSAttributedString(string: "The Best Angle Right Now",
                                     attributes: [.font: UIFont.systemFont(ofSize: 32, weight: .bold)])
        // Large bold type is not a statement that the line is a heading, so nothing is read from it.
        #expect(RichPasteImport.source(fromAttributed: big) == nil)
        #expect(RichPasteImport.source(fromAttributed: NSAttributedString(string: "")) == nil)
    }
}

@MainActor
struct RichPasteFlavorPriorityTests {

    private func pasteboard(_ item: [String: Any]) -> UIPasteboard {
        let pasteboard = UIPasteboard.withUniqueName()
        pasteboard.setItems([item])
        return pasteboard
    }

    @Test func asToldToAsToldUsesTheExactSource() {
        let board = pasteboard([
            StructuredTextExport.pasteboardType: Data("# Shopping\n- [x] Eggs".utf8),
            UTType.html.identifier: "<h1>Shopping</h1><ul><li>Eggs</li></ul>",
            UTType.utf8PlainText.identifier: "Shopping\n☑ Eggs"
        ])
        defer { UIPasteboard.remove(withName: board.name) }
        #expect(RichPasteImport.source(from: board) == "# Shopping\n- [x] Eggs")
    }

    @Test func declaredMarkdownIsReadAsMarkdown() {
        let board = pasteboard([
            "net.daringfireball.markdown": "# Alaska\n- Jacket",
            UTType.utf8PlainText.identifier: "# Alaska\n- Jacket"
        ])
        defer { UIPasteboard.remove(withName: board.name) }
        #expect(RichPasteImport.source(from: board) == "# Alaska\n- Jacket")
    }

    @Test func markdownLookingPlainTextIsNeverReadAsMarkdown() {
        let board = pasteboard([UTType.utf8PlainText.identifier: "**Overview**\n\n| a | b |\n| - | - |"])
        defer { UIPasteboard.remove(withName: board.name) }
        #expect(RichPasteImport.source(from: board) == nil)
    }

    @Test func htmlIsPreferredToPlainText() {
        let board = pasteboard([
            UTType.html.identifier: "<h1>Shopping</h1><ul><li>Eggs</li></ul>",
            UTType.utf8PlainText.identifier: "Shopping\nEggs"
        ])
        defer { UIPasteboard.remove(withName: board.name) }
        #expect(RichPasteImport.source(from: board) == "# Shopping\n- Eggs")
    }

    @Test func plainTextAloneIsLeftToTheSystemPaste() {
        let board = pasteboard([UTType.utf8PlainText.identifier: "The Best Angle Right Now\nInstead of"])
        defer { UIPasteboard.remove(withName: board.name) }
        #expect(RichPasteImport.source(from: board) == nil)
    }

    /// The narrow truth about plain text, and the accepted limitation next to it. Nothing here adds
    /// structure — plain text is left to the system paste, which inserts it character-for-character.
    /// The markers it already contains are then read by the source format itself, which is a property of
    /// `body` being the canonical source, not of anything inferred at paste time (RULES.md §4).
    @Test func plainTextIsNeverReadForStructureEvenWhenItHoldsMarkers() {
        let copied = "# this isn't a heading\n- this isn't a bullet"
        let board = pasteboard([UTType.utf8PlainText.identifier: copied])
        defer { UIPasteboard.remove(withName: board.name) }

        #expect(RichPasteImport.source(from: board) == nil, "paste must add nothing to plain text")
        // What the note then holds is exactly what was copied — and the format reads its own markers.
        #expect(MarkupDocument(copied).lines.map(\.kind) == [.heading, .bullet])
        #expect(MarkupDocument(copied).visibleText() == "this isn't a heading\nthis isn't a bullet")
    }

    @Test func structurelessHtmlIsLeftToTheSystemPaste() {
        let board = pasteboard([
            UTType.html.identifier: "<p>one sentence</p>",
            UTType.utf8PlainText.identifier: "one sentence"
        ])
        defer { UIPasteboard.remove(withName: board.name) }
        #expect(RichPasteImport.source(from: board) == nil)
    }

    @Test func anEmptyPasteboardAsksForNothing() {
        let board = UIPasteboard.withUniqueName()
        defer { UIPasteboard.remove(withName: board.name) }
        #expect(RichPasteImport.source(from: board) == nil)
    }
}

struct RichPasteInsertionTests {

    @Test func pastedStructureLandsAsStructureInAnEmptyNote() throws {
        let source = RichPasteHTML.source(from: "<h1>Shopping</h1><ul><li>Eggs</li></ul>")
        let result = DocumentAction.pasteStructured(try #require(source), text: "",
                                                    selection: NSRange(location: 0, length: 0))
        #expect(result.text == "# Shopping\n- Eggs")
        #expect(MarkupDocument(result.text).visibleText() == "Shopping\nEggs")
    }

    @Test func pastingMidLineNeverPutsAMarkerInsideALine() throws {
        let source = RichPasteHTML.source(from: "<h1>Shopping</h1><ul><li>Eggs</li></ul>")
        let result = DocumentAction.pasteStructured(try #require(source), text: "Buy ",
                                                    selection: NSRange(location: 4, length: 0))
        #expect(result.text == "Buy Shopping\n- Eggs")
    }
}

struct RichPasteSizeTests {

    /// A page pasted out of a browser can be large, and paste happens on the main thread while the
    /// writer waits. A long document has to come back whole, and quickly.
    @Test func aLongDocumentIsConvertedWholeAndQuickly() {
        var html = "<h1>Long</h1>"
        for index in 1...4_000 { html += "<ul><li>item \(index)</li></ul><p>note \(index)</p>" }

        let started = Date()
        let source = RichPasteHTML.source(from: html)
        let elapsed = Date().timeIntervalSince(started)

        let lines = source?.components(separatedBy: "\n") ?? []
        #expect(lines.first == "# Long")
        #expect(lines.last == "note 4000")
        #expect(lines.filter { $0.hasPrefix("- ") }.count == 4_000)
        #expect(elapsed < 2.0, "converting a long paste took \(elapsed)s")
    }
}
