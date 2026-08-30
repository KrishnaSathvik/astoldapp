import XCTest

/// The two defects a physical iPhone found, held down so they cannot come back:
/// a writing toolbar that floated over the line being written, and a table that showed the reader its
/// own storage.
final class EditorPresentationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func body(_ app: XCUIApplication) -> XCUIElement { app.textViews.firstMatch }

    private func openSeededTables() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedTableDemo", "-openSeededNote", "-hasCompletedWelcome", "YES"]
        app.launch()
        return app
    }

    // MARK: The toolbar takes its room rather than floating over the note

    /// The invariant, stated as geometry: the body's viewport ends *above* the writing toolbar.
    ///
    /// It used to end above the keyboard, with the toolbar painted over the last 70-odd points of it —
    /// so UIKit would happily scroll the line being typed to a position it considered visible and the
    /// writer could not see. Asserting the frames is the direct test of that; asserting "the text looks
    /// fine" would not have caught it either time.
    func testTheWritingToolbarNeverCoversTheLineBeingWritten() {
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        for line in 1...16 {
            field.typeText("Line \(line) of a note long enough to run well past one screen.\n")
        }

        let mic = app.buttons["Start recording"]
        XCTAssertTrue(mic.waitForExistence(timeout: 5), "the writing toolbar is not on screen")
        XCTAssertLessThanOrEqual(field.frame.maxY, mic.frame.minY,
                                 "the body's viewport runs underneath the writing toolbar")
    }

    /// And with the keyboard away, the mic-only state has to clear the last paragraph too.
    func testTheReadingToolbarDoesNotCoverTheEndOfTheNote() {
        let app = openSeededTables()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")

        let mic = app.buttons["Start recording"]
        XCTAssertTrue(mic.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(field.frame.maxY, mic.frame.minY,
                                 "the note runs underneath the reading toolbar")
    }

    // MARK: A table reads as a table

    /// A table small enough to read is read in full — and it is a real view, so its rows are what
    /// VoiceOver finds, each cell spoken with the column it belongs to.
    func testATableThatFitsIsReadInFull() {
        let app = openSeededTables()
        XCTAssertTrue(body(app).waitForExistence(timeout: 15))

        let row = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "the expense table's rows are not on the page as a table")
    }

    /// A table too wide for the phone shows what it can and says what it is holding back. Tapping it
    /// opens the reader, which is where the whole grid lives.
    func testAWideTableIsPreviewedAndOpensTheReader() {
        let app = openSeededTables()
        XCTAssertTrue(body(app).waitForExistence(timeout: 15))

        let preview = app.buttons["Table, 3 rows, 7 columns"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "the seven-column itinerary is not being previewed")
        preview.tap()

        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "tapping the preview did not open the reader")
        done.tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "the preview did not come back")
    }

    /// A table is drawn on the note page and nowhere else, so every *other* surface that shows a note
    /// as text has to show the cells rather than the pipes they are stored in. Home read
    /// `| Day | Date | Schedule |` straight out of `body` until 2026-08-21.
    func testHomeShowsATablesCellsAndNeverItsSource() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedTableDemo", "-hasCompletedWelcome", "YES"]
        app.launch()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Alaska itinerary")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "the seeded note is not on Home")

        let pipes = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "| Day"))
        XCTAssertEqual(pipes.count, 0, "Home is showing the table's pipe source")

        let rule = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "| --- |"))
        XCTAssertEqual(rule.count, 0, "Home is showing the table's delimiter row")
    }

    /// Giving the keyboard up leaves every table exactly as it already was: a grid.
    ///
    /// Rewritten 2026-08-26. This asserted that the table *came back* after the caret replaced it with
    /// pipe rows — a contract that no longer exists. A table is now **always** drawn as its grid,
    /// "reading, typing elsewhere in the note, or editing the table itself" (`RULES.md`), so there is
    /// nothing to restore. What is worth holding down is the pair of things that could still go wrong:
    /// leaving the body must not de-render a table, and it must not strand an open cell editor.
    func testLeavingTheBodyLeavesEveryTableAGrid() {
        let app = openSeededTables()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        let preview = app.buttons["Table, 3 rows, 7 columns"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))

        let expenses = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(expenses.waitForExistence(timeout: 5))

        // The cell editor is one re-used `UITextField`, hidden until a cell is tapped — so its arrival
        // in the accessibility tree is the evidence that the tap opened the editor rather than doing
        // nothing at all.
        let fieldsBefore = app.textFields.count
        expenses.tap()
        XCTAssertEqual(app.textFields.count, fieldsBefore + 1,
                       "tapping a cell did not open the in-grid cell editor")
        XCTAssertTrue(expenses.exists, "editing a cell de-rendered the table")

        // Handing the keyboard to the title takes it off the body. The title rides the body's scroll
        // (`NotePageView`), so it has to be brought back into view before it can be tapped.
        let title = app.textFields["Title"]
        for _ in 0..<4 where !title.isHittable { field.swipeDown() }
        XCTAssertTrue(title.isHittable, "could not scroll the title back into view")
        title.tap()

        XCTAssertTrue(expenses.waitForExistence(timeout: 5),
                      "leaving the body did not leave the table a grid")
        XCTAssertTrue(preview.exists, "leaving the body de-rendered the other table")
    }

    /// Handing the keyboard to the title commits the open cell.
    ///
    /// One of the exits that used to lose text: the title is a different field, so taking focus
    /// resigned the cell's field, and nothing was listening for that (fixed 2026-08-27).
    func testACellEditSurvivesTappingTheTitle() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedTableDemo", "-openSeededNote",
                               "-exposeSourceForTests", "-hasCompletedWelcome", "YES"]
        app.launch()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        let expenses = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(expenses.waitForExistence(timeout: 10))
        expenses.tap()
        app.typeText("ZZQQ")

        // Scroll first, unconditionally, then tap by coordinate. Asking `isHittable` while the title
        // is still above the viewport raises "activation point invalid" rather than answering false,
        // which fails the test on the harness rather than on the product.
        for _ in 0..<5 { field.swipeDown() }
        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "the title never came into view")
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue((field.value as? String ?? "").contains("ZZQQ"),
                      "tapping the title did not commit the cell edit")
    }

    /// Scrolling a table out of sight and back must never mean "discard what I typed".
    ///
    /// Card retirement inside `TableCardPresenter.sync` used to pass `commit: false`, so ordinary card
    /// churn could drop an open cell. Asserted across a full round trip — scroll away, scroll back,
    /// leave the note, reopen it — because that is the chain a person actually performs, and the
    /// discard could hide in any link of it.
    func testACellEditSurvivesScrollingTheCardOutOfSight() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedTableDemo",
                               "-exposeSourceForTests", "-hasCompletedWelcome", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        guard let row = app.buttons.allElementsBoundByIndex.first(where: {
            !["New note", "New voice note", "Profile", "Open calendar"].contains($0.label)
        }) else { return XCTFail("no note row on Home") }
        row.tap()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let expenses = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(expenses.waitForExistence(timeout: 10))
        expenses.tap()
        app.typeText("ZZQQ")

        for _ in 0..<4 { field.swipeUp() }
        for _ in 0..<4 { field.swipeDown() }

        app.buttons["Back to notes"].tap()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 10), "did not return Home")
        guard let again = app.buttons.allElementsBoundByIndex.first(where: {
            !["New note", "New voice note", "Profile", "Open calendar"].contains($0.label)
        }) else { return XCTFail("no note row on Home after Back") }
        again.tap()

        let reopened = body(app)
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        XCTAssertTrue((reopened.value as? String ?? "").contains("ZZQQ"),
                      "scrolling the card out of sight discarded the cell edit")
    }

    /// Back is not a cancel (`RULES.md` §4) — so a cell edit must survive leaving the note.
    ///
    /// **Known to fail as of 2026-08-27. This is a real defect, not a stale expectation, and it loses
    /// the writer's words.** Type into a table cell, tap Back, reopen the note: the text is gone. An
    /// open cell lives in the card's own `UITextField` until something commits it, and the only things
    /// that do are Return, Tab, tapping another cell, tapping elsewhere in the body, and Share
    /// (`commitAndRead`). Leaving the note is not on that list, so `body` never receives the edit and
    /// autosave faithfully persists a note that never contained it.
    ///
    /// Left failing deliberately, pending a decision on the fix — no product code was changed.
    func testACellEditSurvivesLeavingTheNote() {
        // No `-openSeededNote`: that routes straight into an editor with no Home behind it, so Back
        // has nowhere to go. Launch to Home and open the note by tapping it, like a person would.
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedTableDemo",
                               "-exposeSourceForTests", "-hasCompletedWelcome", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        guard let row = app.buttons.allElementsBoundByIndex.first(where: {
            !["New note", "New voice note", "Profile", "Open calendar"].contains($0.label)
        }) else { return XCTFail("no note row on Home") }
        row.tap()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let expenses = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(expenses.waitForExistence(timeout: 10))
        expenses.tap()
        app.typeText("ZZQQ")

        // Back is not a cancel (RULES.md §4). Leaving the note must keep what was typed.
        app.buttons["Back to notes"].tap()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 10), "did not return Home")
        guard let again = app.buttons.allElementsBoundByIndex.first(where: {
            !["New note", "New voice note", "Profile", "Open calendar"].contains($0.label)
        }) else { return XCTFail("no note row on Home after Back") }
        again.tap()

        let reopened = body(app)
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        XCTAssertTrue((reopened.value as? String ?? "").contains("ZZQQ"),
                      "leaving the note lost the cell edit — Back is not a cancel (RULES.md §4)")
    }

    // MARK: Editing one block leaves every other block alone
    //
    // The rule these hold down has been through two corrections, and the tests below have now caught up
    // to the second. It first read "does the body have the keyboard", full stop — so a note of thirteen
    // tables turned into thirteen blocks of pipe rows because someone added a sentence at the end of it.
    // It then read "only the block the caret is inside shows its source" (amended 2026-08-23), which is
    // what most of this file was written against.
    //
    // It now reads: **no block ever shows its source.** A table is always a grid and a code block always
    // looks like code, including while being edited; a cell is edited in place in the grid, and code is
    // edited in place with its fences hidden. Storage is storage, and a reader must never have to look
    // past it. Tests asserting the 2026-08-23 contract were rewritten on 2026-08-26 — they were failing
    // against correct code, which is the most expensive kind of stale test there is.

    /// Typing in prose must leave every table on the page a table.
    ///
    /// `-caretAtEnd` rather than a tap at a guessed coordinate: it opens the note with the body already
    /// focused and the caret on the last line, which in this fixture is a paragraph well below both
    /// tables. A normalized tap near the top of the body lands in the header inset the page reserves
    /// for the date and title, so it focused the *title* and the assertion below caught it.
    func testTypingInProseLeavesEveryTableRendered() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedTableDemo", "-openSeededNote", "-caretAtEnd",
                               "-exposeSourceForTests", "-hasCompletedWelcome", "YES"]
        app.launch()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let preview = app.buttons["Table, 3 rows, 7 columns"]
        let expenses = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10), "the itinerary is not being previewed")
        XCTAssertTrue(expenses.waitForExistence(timeout: 10), "the expense table is not a card")

        // Proof the body actually holds the keyboard. `app.keyboards` cannot be asked: it reports
        // nothing when the simulator has a hardware keyboard attached.
        app.typeText("X")
        XCTAssertTrue((field.value as? String ?? "").hasSuffix("X"),
                      "the body does not have the caret, so this proves nothing about editing")

        XCTAssertTrue(preview.exists, "typing in prose de-rendered the itinerary table")
        XCTAssertTrue(expenses.exists, "typing in prose de-rendered the expense table")
    }

    /// Editing a cell in one table leaves that table a grid — and every other table untouched.
    ///
    /// Rewritten 2026-08-26: this required the edited table to vanish into pipe rows. It must now do the
    /// opposite, so the assertion is inverted rather than deleted — the table the caret is in is exactly
    /// the one most at risk of showing its storage.
    func testEditingACellLeavesEveryTableAGrid() {
        let app = openSeededTables()
        XCTAssertTrue(body(app).waitForExistence(timeout: 15))

        let preview = app.buttons["Table, 3 rows, 7 columns"]
        let expenses = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(expenses.waitForExistence(timeout: 10))

        let fieldsBefore = app.textFields.count
        expenses.tap()
        XCTAssertEqual(app.textFields.count, fieldsBefore + 1,
                       "tapping a cell did not open the in-grid cell editor")

        XCTAssertTrue(expenses.exists, "the edited table stopped being a grid")
        XCTAssertTrue(preview.exists, "editing the expense table de-rendered the itinerary table")

        // The delimiter row is unambiguous storage: no cell can contain it, so finding one on screen
        // means a table flipped to its source.
        let rule = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "| --- |"))
        XCTAssertEqual(rule.count, 0, "a table showed its delimiter row while a cell was edited")
    }

    /// A tap outside a cell **commits** and leaves (`RULES.md`).
    ///
    /// **Known to fail as of 2026-08-26 — this is a product gap, not a stale expectation.** Unlike the
    /// four tests rewritten around it, this one is not asserting an old contract: it is asserting the
    /// rule exactly as written, and the rule is not implemented. `TableCardView`'s delegate has no
    /// `textFieldDidEndEditing`, and `TableCardPresenter.endCellEditing()` has one caller —
    /// `commitAndRead`, which only **Share** invokes. So nothing commits an open cell when the writer
    /// taps away, and the typed text never reaches `body`.
    ///
    /// Asserted on the note's own text rather than on the field disappearing, because losing the edit
    /// is the harm; a lingering field is only how you notice. Left failing deliberately, pending a
    /// decision on the fix — no product code was changed to make it pass.
    func testATapOutsideACellCommitsTheEdit() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedTableDemo", "-openSeededNote",
                               "-exposeSourceForTests", "-hasCompletedWelcome", "YES"]
        app.launch()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        let expenses = app.otherElements["Expense, 9 nights lodging, 2 people, $2,400-$3,600"]
        XCTAssertTrue(expenses.waitForExistence(timeout: 10))
        expenses.tap()
        app.typeText("ZZQQ")

        // Aim at the paragraph under the *other* table — derived from a real element's frame, because a
        // normalized tap near the top of the body lands in the header inset and focuses the title.
        let preview = app.buttons["Table, 3 rows, 7 columns"]
        XCTAssertTrue(preview.exists, "the itinerary card is not on screen to aim from")
        let below = preview.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: below.midX, dy: below.maxY + 24))
            .tap()

        XCTAssertTrue((field.value as? String ?? "").contains("ZZQQ"),
                      "a tap outside the cell did not commit the edit — the typed text is not in the note")

        // Deliberately *not* `expenses.exists`: a successful commit rewrites the row's accessibility
        // label, so asserting the old label would fail precisely when the feature works. Grid-ness is
        // checked label-independently instead — the delimiter row is storage no cell can contain, and
        // `-exposeSourceForTests` puts raw source in the body's `value`, never a `label`.
        let stillARow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "nights lodging"))
        XCTAssertGreaterThan(stillARow.count, 0, "the table stopped being a grid when the caret left it")
        let rule = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "| --- |"))
        XCTAssertEqual(rule.count, 0, "the table showed its delimiter row")
    }
}

/// The same rule, for code blocks.
final class CodeBlockPresentationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func body(_ app: XCUIApplication) -> XCUIElement { app.textViews.firstMatch }

    private func openSeededCode(exposingSource: Bool = false,
                                caretAtEnd: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedCodeDemo", "-openSeededNote",
                               "-hasCompletedWelcome", "YES"]
        if exposingSource { app.launchArguments.append("-exposeSourceForTests") }
        if caretAtEnd { app.launchArguments.append("-caretAtEnd") }
        app.launch()
        return app
    }

    /// A code block is read as a card, with its code one tap from the pasteboard — and never as its
    /// fences, which are how the note stores it.
    func testCodeIsReadAsACardAndNotAsItsFences() {
        let app = openSeededCode()
        XCTAssertTrue(body(app).waitForExistence(timeout: 15))

        XCTAssertTrue(app.buttons["Copy Code"].waitForExistence(timeout: 10),
                      "the code block is not drawn as a card")
        let fences = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "```"))
        XCTAssertEqual(fences.count, 0, "a fence reached the reader")
    }

    /// Typing in prose leaves the code block — and the table beside it — rendered.
    func testTypingInProseLeavesTheCodeBlockRendered() {
        let app = openSeededCode(exposingSource: true, caretAtEnd: true)
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        let copy = app.buttons["Copy Code"]
        XCTAssertTrue(copy.waitForExistence(timeout: 10), "the code block is not a card")

        app.typeText("X")
        XCTAssertTrue((field.value as? String ?? "").hasSuffix("X"),
                      "the body does not have the caret, so this proves nothing about editing")

        XCTAssertTrue(copy.exists, "typing in prose de-rendered the code block")
    }

    /// The block being edited MUST still look like code.
    ///
    /// Rewritten 2026-08-26, and this one asserted the exact inverse of the shipped rule: it waited for
    /// **Copy Code** to disappear, while `RULES.md` requires that "the ground, the monospaced face, the
    /// language label, **Copy Code**, indentation, and **syntax colour** MUST all stay on" while a block
    /// is edited. The old contract — tap a card, get ```` ```python ```` and a wall of unstyled text —
    /// was itself the defect that amendment fixed (2026-08-24, Item 5).
    func testTheCodeCardStaysACardWhileItsCodeIsEdited() {
        let app = openSeededCode()
        XCTAssertTrue(body(app).waitForExistence(timeout: 15))

        let copy = app.buttons["Copy Code"]
        XCTAssertTrue(copy.waitForExistence(timeout: 10))

        // A card is inert except for Copy Code, so this tap goes through it and puts the caret in the
        // code underneath — which is the only way into a block whose source the card is covering.
        //
        // The label reads `Python`, not the `python` the fence stated: since 2026-08-24 the card shows
        // the reader's spelling of the language the source named (RULES.md §7).
        app.staticTexts["Python"].tap()

        XCTAssertTrue(copy.exists, "editing the block took Copy Code away")
        XCTAssertTrue(app.staticTexts["Python"].exists, "editing the block took the language label away")

        // Fences are storage. They are hidden while the block is edited, not revealed.
        let fences = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "```"))
        XCTAssertEqual(fences.count, 0, "a fence reached the reader while the block was edited")
    }

    /// …and the tap really did get into the code. Without this, the test above would pass just as
    /// happily if a touch on the card did nothing at all — which is the one failure mode that *would*
    /// be a product regression rather than a stale expectation.
    func testTappingACodeCardPutsTheCaretInTheCode() {
        let app = openSeededCode(exposingSource: true)
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Copy Code"].waitForExistence(timeout: 10))

        let before = field.value as? String ?? ""
        app.staticTexts["Python"].tap()
        app.typeText("X")

        let after = field.value as? String ?? ""
        XCTAssertNotEqual(after, before, "the tap did not put the caret anywhere — nothing was typed")
        XCTAssertTrue(after.contains("X"), "the typed character did not reach the note")
        XCTAssertTrue(app.buttons["Copy Code"].exists, "typing in the block de-rendered the card")
    }
}
