import XCTest

/// The flow that produced the ghost row on Home: existing note → New Note → type nothing → Back.
///
/// This covers the round trip end to end — Home comes back intact, the untouched draft leaves no
/// row behind, and `finish()` still removes it. It deliberately does **not** claim to catch the
/// transient frame itself: the ghost row lived only between Back and the deletion propagating, which
/// is not something XCUI can be pointed at. `NoteVisibilityTests` pins that state down directly by
/// setting up the same draft and asking what Home would render.
final class EmptyDraftHomeUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launched() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-seedSampleNotes", "-hasCompletedWelcome", "YES"]
        app.launch()
        return app
    }

    /// Every row on Home carries the note's text as its label, so a row for a note with nothing in it
    /// is a button with nothing to say.
    private func blankRowCount(_ app: XCUIApplication) -> Int {
        app.buttons.matching(NSPredicate(format: "label == ''")).count
    }

    func testLeavingAnUntouchedNewNoteLeavesHomeExactlyAsItWas() {
        let app = launched()
        let compose = app.buttons["New note"]
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "Home did not appear")

        let firstRow = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "Alaska")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "seeded note row missing")
        let originalTop = firstRow.frame.origin.y
        let originalBlankRows = blankRowCount(app)

        compose.tap()
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 15), "editor did not open")

        // Nothing typed. Back is the moment the draft is abandoned.
        let back = app.buttons["Back to notes"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back button missing")
        back.tap()

        XCTAssertTrue(compose.waitForExistence(timeout: 15), "did not return to Home")
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "the existing note is gone from Home")
        XCTAssertEqual(firstRow.frame.origin.y, originalTop, accuracy: 1.0,
                       "the existing note moved — something else took a row above it")
        XCTAssertEqual(blankRowCount(app), originalBlankRows,
                       "an empty draft is still rendered as a row on Home")
    }

    /// Twice over, because the reported artifact showed up on repeated New Note / Back trips.
    func testRepeatedNewNoteAndBackDoesNotAccumulateRows() {
        let app = launched()
        let compose = app.buttons["New note"]
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "Home did not appear")
        let firstRow = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "Alaska")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "seeded note row missing")
        let originalTop = firstRow.frame.origin.y

        for pass in 1...3 {
            compose.tap()
            XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 15),
                          "[pass \(pass)] editor did not open")
            app.buttons["Back to notes"].tap()
            XCTAssertTrue(compose.waitForExistence(timeout: 15), "[pass \(pass)] did not return to Home")
        }

        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "the existing note is gone from Home")
        XCTAssertEqual(firstRow.frame.origin.y, originalTop, accuracy: 1.0,
                       "Home reflowed — abandoned drafts accumulated rows above the existing note")
    }
}
