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

    /// The boundary, both ways. Taking the keyboard puts the note back into its own words — a table
    /// being edited is text being edited, and the caret has to be somewhere the writer can see it.
    /// Giving the keyboard up puts the tables back.
    func testEditingShowsTheSourceAndLeavingRestoresTheTable() {
        let app = openSeededTables()
        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15))

        let preview = app.buttons["Table, 3 rows, 7 columns"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))

        // The last paragraph, well below both tables: a tap there is a tap on prose, and the body takes
        // the keyboard. Asserted through the card rather than through `app.keyboards`, which reports
        // nothing when a hardware keyboard is attached to the simulator.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.97)).tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: preview)
        wait(for: [gone], timeout: 5)

        // Handing the keyboard to the title takes it off the body, which is what restores the cards.
        // The title rides the body's scroll (`NotePageView`), so it has to be brought back into view
        // before it can be tapped.
        let title = app.textFields["Title"]
        for _ in 0..<4 where !title.isHittable { field.swipeDown() }
        XCTAssertTrue(title.isHittable, "could not scroll the title back into view")
        title.tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 5),
                      "leaving the body did not put the table back")
    }
}
