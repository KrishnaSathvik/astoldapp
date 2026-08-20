import XCTest

/// Discoverability without chrome: the contextual `Aa` Style menu and the reference folded inside it.
///
/// The absence assertions matter as much as the presence ones. RULES.md §1 forbids permanent
/// formatting furniture in the editor, so "the Style control is gone while reading" is a product rule
/// under test, not an incidental detail — a regression that leaves it visible would quietly turn a
/// contextual affordance into the persistent ribbon the rules refuse.
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

    // MARK: The empty note teaches nothing

    /// The marker cheat-sheet went with the Style menu (RULES.md §7). An empty note is a place to
    /// start writing, not a syntax lesson.
    func testEmptyNewNoteShowsOnlyThePlaceholder() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.descendants(matching: .any)["Body placeholder"].waitForExistence(timeout: 8),
                      "an empty note should still say where to start")
        XCTAssertFalse(app.descendants(matching: .any)["Writing syntax hint"].exists,
                       "the empty-note syntax hint should be gone")
    }

    func testTypingRemovesThePlaceholder() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        let placeholder = app.descendants(matching: .any)["Body placeholder"]
        XCTAssertTrue(placeholder.waitForExistence(timeout: 8), "placeholder should start visible")

        app.typeText("a")
        XCTAssertTrue(placeholder.waitForNonExistence(timeout: 8),
                      "the first keystroke should dismiss the placeholder")
    }

    // MARK: The contextual Style control

    func testStyleControlIsAbsentWhileReading() {
        let app = launchedIntoSeededNote()
        XCTAssertFalse(app.buttons["Style"].exists,
                       "reading a note must keep the editor chrome clean")
    }

    func testStyleControlAppearsWhileWritingInTheBody() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.buttons["Style"].waitForExistence(timeout: 8),
                      "the Style control should be reachable while writing")
    }

    /// A title has no block structure, so styling it means nothing. The control follows the *body*'s
    /// caret, not merely "is a keyboard up".
    func testStyleControlIsAbsentWhileTheTitleHasTheCaret() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.buttons["Style"].waitForExistence(timeout: 8),
                      "the Style control should start out available")

        tap(app.textFields["Title"], "Title field")
        XCTAssertTrue(app.buttons["Style"].waitForNonExistence(timeout: 8),
                      "styling a title is meaningless — the control must not be offered")
        XCTAssertTrue(app.keyboards.element.exists,
                      "the title is still being edited — only the Style control went away")
    }

    /// Leaving the writing state takes the control with it. There is no Done to press, so the exit
    /// under test is the real one: navigating Back.
    func testStyleControlDisappearsWhenTheNoteIsLeft() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        let style = app.buttons["Style"]
        XCTAssertTrue(style.waitForExistence(timeout: 8), "the control should be present while writing")

        app.typeText("Something")
        tap(app.buttons["Back to notes"], "Back to notes")
        XCTAssertTrue(style.waitForNonExistence(timeout: 8),
                      "leaving the note should take the Style control with it")
    }

    /// The standalone `?` was folded into the Style menu. It must not survive as a second control —
    /// two pieces of chrome where the design allows one.
    func testTheStandaloneHelpButtonIsGone() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.buttons["Style"].waitForExistence(timeout: 8), "editor did not open")
        XCTAssertFalse(app.buttons["Writing help"].exists,
                       "the standalone ? should have been folded into the Style menu")
    }

    // MARK: The menu

    func testStyleMenuOffersTheSixStructuresAndNothingElse() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Style"], "Style")

        for name in ["Paragraph", "Heading", "Subheading", "Bulleted List", "Numbered List", "Checklist"] {
            XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 8),
                          "the Style menu is missing \(name)")
        }
        // Inline rich text is a different category and is not in V1 (RULES.md §7).
        for absent in ["Bold", "Italic", "Underline", "Strikethrough", "Highlight"] {
            XCTAssertFalse(app.buttons[absent].exists,
                           "the Style menu must not offer \(absent)")
        }
    }

    /// The menu says what the line already is, so a writer can see the structure they are standing in
    /// rather than guessing.
    func testStyleMenuChecksTheCurrentBlock() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        app.typeText("# Alaska")

        tap(app.buttons["Style"], "Style")
        let heading = app.buttons["Heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 8), "the Style menu did not open")
        XCTAssertTrue(heading.isSelected, "the current block should be checked")
        XCTAssertFalse(app.buttons["Paragraph"].isSelected, "only the current block should be checked")
    }

    /// The reference the `?` used to hold, one tap deeper. Losing the keyboard to a sheet costs
    /// nothing here, because nothing on it applies anything.
    func testWritingHelpIsReachableThroughTheStyleMenu() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Style"], "Style")
        tap(app.buttons["Writing help…"], "Writing help…")

        XCTAssertTrue(app.navigationBars["Writing in As Told"].waitForExistence(timeout: 8),
                      "the writing-help sheet did not open from the Style menu")
        for name in ["Heading", "Subheading", "Bulleted List", "Numbered List", "Checklist"] {
            XCTAssertTrue(app.staticTexts[name].exists, "typing reference is missing \(name)")
        }
        for command in ["New paragraph", "New line", "Heading", "Subheading", "Bullet list",
                        "Numbered list", "Checklist", "Next item", "End list"] {
            XCTAssertTrue(app.staticTexts["“\(command)”"].exists,
                          "voice reference is missing “\(command)”")
        }
    }

    /// The sheet stays reference-only. Applying a structure is the menu's job; a second path to it
    /// here would be two formatting systems for one document.
    func testHelpSheetOffersNoFormattingActions() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Style"], "Style")
        tap(app.buttons["Writing help…"], "Writing help…")
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
