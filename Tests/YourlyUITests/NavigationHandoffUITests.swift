import XCTest

/// Home's chrome must not survive into a pushed editor.
///
/// Regression cover for a broken navigation handoff (2026-08-19): tapping New note pushed an editor
/// that rendered `model == nil` for its first frames — no date, no title, no toolbar — while Home's
/// `Search notes` field stayed anchored to the bottom of the screen and Home's profile / calendar /
/// compose controls floated over the editor's content, all of it disappearing a moment later. Two
/// ownership problems: the editor was not ready before the route activated, and Home's chrome was
/// declared on the same view as the stack's destinations.
final class NavigationHandoffUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func assertHomeChromeIsGone(_ app: XCUIApplication, _ context: String) {
        // Editor content is present…
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 10),
                      "[\(context)] editor body missing")
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 10),
                      "[\(context)] editor toolbar missing")
        // …and none of Home's chrome is.
        XCTAssertFalse(app.searchFields.firstMatch.exists,
                       "[\(context)] Home's search field is still in the editor")
        for label in ["New note", "Open calendar", "Profile"] {
            XCTAssertFalse(app.buttons[label].exists,
                           "[\(context)] Home's '\(label)' control is still in the editor")
        }
    }

    private func launched(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-hasCompletedWelcome", "YES"] + extra
        app.launch()
        return app
    }

    func testComposeFromAnEmptyHomeHandsOverCleanly() {
        let app = launched()
        let compose = app.buttons["New note"]
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "Home did not appear")
        compose.tap()
        assertHomeChromeIsGone(app, "empty Home")
    }

    func testComposeFromAPopulatedHomeHandsOverCleanly() {
        let app = launched(["-seedSampleNotes"])
        let compose = app.buttons["New note"]
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "Home did not appear")
        compose.tap()
        assertHomeChromeIsGone(app, "populated Home")
    }

    func testOpeningAnExistingNoteHandsOverCleanly() {
        let app = launched(["-seedSampleNotes"])
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        let row = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Alaska")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "seeded note row missing")
        row.tap()
        assertHomeChromeIsGone(app, "existing note")
    }

    /// Back to Home restores Home's chrome, and composing again is still clean.
    func testBackThenComposeAgainHandsOverCleanly() {
        let app = launched(["-seedSampleNotes"])
        let compose = app.buttons["New note"]
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "Home did not appear")
        compose.tap()
        assertHomeChromeIsGone(app, "first compose")

        app.buttons["Back to notes"].tap()
        XCTAssertTrue(compose.waitForExistence(timeout: 10), "Home chrome did not come back")
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5),
                      "Home's search field did not come back")

        compose.tap()
        assertHomeChromeIsGone(app, "second compose")
    }
}
