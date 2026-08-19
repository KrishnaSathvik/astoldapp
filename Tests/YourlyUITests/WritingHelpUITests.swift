import XCTest

/// Discoverability without chrome: the empty-note hint and the contextual `?`.
///
/// The absence assertions matter as much as the presence ones. RULES.md §1 forbids permanent
/// formatting furniture in the editor, so "the `?` is gone while reading" is a product rule under
/// test, not an incidental detail — a regression that leaves it visible would quietly turn a
/// contextual affordance into the persistent one the rules refuse.
final class WritingHelpUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore"] + extraArguments
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    /// `-openSeededNote` routes past Home into the editor, so this waits for the editor instead.
    private func launchedIntoSeededNote() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore",
                               "-seedSampleNotes", "-openSeededNote"]
        app.launch()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 15),
                      "the seeded note did not open")
        return app
    }

    private func tap(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 8) {
        guard element.waitForExistence(timeout: timeout) else {
            return XCTFail("missing element: \(message)")
        }
        element.tap()
    }

    // MARK: The empty-note hint

    func testEmptyNewNoteShowsTheSyntaxHint() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.descendants(matching: .any)["Writing syntax hint"].waitForExistence(timeout: 8),
                      "An empty new note should teach the markers")
    }

    /// The first keystroke is the dismissal — no button, no lingering.
    func testTypingRemovesTheSyntaxHint() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        let hint = app.descendants(matching: .any)["Writing syntax hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 8), "hint should start visible")

        app.typeText("a")
        XCTAssertTrue(hint.waitForNonExistence(timeout: 8),
                      "the first keystroke should dismiss the hint")
    }

    /// A note with words in it is someone's writing, not a teaching surface.
    func testExistingNoteNeverShowsTheSyntaxHint() {
        let app = launchedIntoSeededNote()
        XCTAssertFalse(app.descendants(matching: .any)["Writing syntax hint"].exists,
                       "an existing note must not show the hint")
    }

    // MARK: The contextual ?

    func testHelpIsAbsentWhileReading() {
        let app = launchedIntoSeededNote()
        XCTAssertFalse(app.buttons["Writing help"].exists,
                       "reading a note must keep the editor chrome clean")
    }

    func testHelpAppearsWhileEditing() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.buttons["Writing help"].waitForExistence(timeout: 8),
                      "writing help should be reachable while editing")
    }

    /// Dismissing the keyboard is leaving the writing state, so the help control leaves with it.
    func testHelpDisappearsWhenEditingEnds() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        let help = app.buttons["Writing help"]
        XCTAssertTrue(help.waitForExistence(timeout: 8), "help should be present while editing")

        tap(app.buttons["Dismiss keyboard"], "Done")
        XCTAssertTrue(help.waitForNonExistence(timeout: 8),
                      "leaving the writing state should take the help control with it")
    }

    // MARK: The reference itself

    func testHelpSheetListsTypingMarkersAndEveryVoiceCommand() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Writing help"], "Writing help")

        XCTAssertTrue(app.staticTexts["Heading"].waitForExistence(timeout: 8),
                      "the sheet did not open")
        for name in ["Heading", "Subheading", "Bullet list", "Numbered list", "Checklist"] {
            XCTAssertTrue(app.staticTexts[name].exists, "typing reference is missing \(name)")
        }
        // All nine spoken commands, quoted as they appear in the "Say" section.
        for command in ["New paragraph", "New line", "Heading", "Subheading", "Bullet list",
                        "Numbered list", "Checklist", "Next item", "End list"] {
            XCTAssertTrue(app.staticTexts["“\(command)”"].exists,
                          "voice reference is missing “\(command)”")
        }
    }

    /// Reference only. A formatting control here would be the ribbon RULES.md §1 forbids, arriving
    /// one tap deeper than a toolbar.
    func testHelpSheetOffersNoFormattingActions() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Writing help"], "Writing help")
        XCTAssertTrue(app.staticTexts["Heading"].waitForExistence(timeout: 8), "the sheet did not open")

        // Scoped to the sheet's own bar: the editor's chrome is still on screen behind it, and
        // sweeping every navigation bar would assert against the wrong screen.
        let sheetBar = app.navigationBars["Writing in As Told"]
        XCTAssertTrue(sheetBar.exists, "the help sheet should own a titled navigation bar")
        let buttons = sheetBar.buttons.allElementsBoundByIndex
        for button in buttons where button.exists {
            XCTAssertEqual(button.label, "Done",
                           "the help sheet must not offer actions — found “\(button.label)”")
        }
    }
}
