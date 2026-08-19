import XCTest

/// Interactive verification of the structured-editor wiring that unit tests can't reach: typed
/// list continuation and checkbox tapping. Both launch with `-exposeSourceForTests` so the body text
/// view reports its raw source (markers included) as its accessibility value.
final class StructuredEditorUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func body(_ app: XCUIApplication) -> XCUIElement { app.textViews.firstMatch }

    /// Typing one bullet, then Return, continues the list automatically; Return on an empty item exits
    /// back to a plain paragraph. Markers are inserted by the editor, not typed twice.
    func testTypingContinuesAndExitsList() {
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        // "- " starts a bullet; the next line's "- " is added automatically; the blank Return exits.
        field.typeText("- Milk\nEggs\n\nDone")

        XCTAssertEqual(field.value as? String, "- Milk\n- Eggs\nDone")
    }

    /// Tapping a checklist item's checkbox toggles the underlying marker. Typed as the first line so
    /// the checkbox sits at a predictable position (top-left gutter of the body).
    func testTappingCheckboxToggles() {
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        field.typeText("- [ ] Task")
        XCTAssertEqual(field.value as? String, "- [ ] Task", "typing '- [ ] ' should create a checklist item")

        // The checkbox is in the first line's left gutter — tap just inside the text view, top-left.
        let frame = field.frame
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.minX + 8, dy: frame.minY + 20))
            .tap()

        let toggled = expectation(for: NSPredicate(format: "value == %@", "- [x] Task"), evaluatedWith: field)
        wait(for: [toggled], timeout: 5)
    }

    /// Cut then paste inside As Told must round-trip the *structure*, not just the words: the private
    /// pasteboard representation carries the raw source, while other apps only ever see visible text.
    func testCutAndPasteKeepsStructureInsideTheApp() {
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        field.typeText("- [ ] Call Ravi")
        XCTAssertEqual(field.value as? String, "- [ ] Call Ravi")

        tapMenuItem("Select All", in: app, longPressing: field)
        tapMenuItem("Cut", in: app, longPressing: nil)
        let emptied = expectation(for: NSPredicate(format: "value == %@", ""), evaluatedWith: field)
        wait(for: [emptied], timeout: 5)

        tapMenuItem("Paste", in: app, longPressing: field)
        let restored = expectation(for: NSPredicate(format: "value == %@", "- [ ] Call Ravi"), evaluatedWith: field)
        wait(for: [restored], timeout: 5)
    }

    /// Everything outside the structured editor — here the plain title field, and by the same route any
    /// other app — receives the text as the reader sees it: "☐ Call Ravi", never "- [ ] Call Ravi".
    func testCopyGivesPlainFieldsTheVisibleText() {
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()

        let field = body(app)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")
        field.tap()
        field.typeText("- [ ] Call Ravi")

        tapMenuItem("Select All", in: app, longPressing: field)
        tapMenuItem("Copy", in: app, longPressing: nil)

        let title = app.textFields["Title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "title field did not appear")
        title.tap()
        tapMenuItem("Paste", in: app, longPressing: title)

        let pasted = expectation(for: NSPredicate(format: "value == %@", "☐ Call Ravi"), evaluatedWith: title)
        wait(for: [pasted], timeout: 5)
    }

    // MARK: The Style menu

    /// The point of the control: select several lines, pick a structure once, and every selected line
    /// becomes it. Typing the marker would mean doing it three times.
    func testStyleMenuConvertsEverySelectedLine() {
        let app = launchedEditor()
        let field = body(app)
        field.tap()
        field.typeText("Milk\nEggs\nBread")
        XCTAssertEqual(field.value as? String, "Milk\nEggs\nBread")

        tapMenuItem("Select All", in: app, longPressing: field)
        applyStyle("Bullet list", in: app)

        let converted = expectation(for: NSPredicate(format: "value == %@", "- Milk\n- Eggs\n- Bread"),
                                    evaluatedWith: field)
        wait(for: [converted], timeout: 5)
    }

    /// Numbering is not "1." three times: the menu produces the sequence a reader expects.
    func testStyleMenuNumbersASelectionInSequence() {
        let app = launchedEditor()
        let field = body(app)
        field.tap()
        field.typeText("One\nTwo\nThree")

        tapMenuItem("Select All", in: app, longPressing: field)
        applyStyle("Numbered list", in: app)

        let converted = expectation(for: NSPredicate(format: "value == %@", "1. One\n2. Two\n3. Three"),
                                    evaluatedWith: field)
        wait(for: [converted], timeout: 5)
    }

    /// One tap is one thing the writer did, so one undo puts all three lines back. Two undos leaving a
    /// half-converted note would be the editor exposing its own implementation.
    func testUndoingAMultiLineConversionTakesOneStep() {
        let app = launchedEditor()
        let field = body(app)
        field.tap()
        field.typeText("Milk\nEggs\nBread")

        tapMenuItem("Select All", in: app, longPressing: field)
        applyStyle("Bullet list", in: app)
        let converted = expectation(for: NSPredicate(format: "value == %@", "- Milk\n- Eggs\n- Bread"),
                                    evaluatedWith: field)
        wait(for: [converted], timeout: 5)

        app.typeKey("z", modifierFlags: .command)
        let restored = expectation(for: NSPredicate(format: "value == %@", "Milk\nEggs\nBread"),
                                   evaluatedWith: field)
        wait(for: [restored], timeout: 5)
    }

    /// Converting a paragraph under an existing list joins that list rather than restarting it.
    func testStyleMenuContinuesNumberingFromTheListAbove() {
        let app = launchedEditor()
        let field = body(app)
        field.tap()
        // "1. " starts the list, Return continues it to "2. ", and the empty Return exits.
        field.typeText("1. One\nTwo\n\nThree")
        XCTAssertEqual(field.value as? String, "1. One\n2. Two\nThree")

        applyStyle("Numbered list", in: app)
        let continued = expectation(for: NSPredicate(format: "value == %@", "1. One\n2. Two\n3. Three"),
                                    evaluatedWith: field)
        wait(for: [continued], timeout: 5)
    }

    /// Typed markers stay a shortcut for the same operation, not a second system: what the menu makes
    /// is exactly what typing the marker makes.
    func testTappingAndTypingProduceTheSameStructure() {
        let app = launchedEditor()
        let field = body(app)
        field.tap()
        field.typeText("Task")
        applyStyle("Checklist", in: app)

        let converted = expectation(for: NSPredicate(format: "value == %@", "- [ ] Task"),
                                    evaluatedWith: field)
        wait(for: [converted], timeout: 5)
    }

    private func launchedEditor() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-openSampleEditor", "-exposeSourceForTests", "-resetStore"]
        app.launch()
        XCTAssertTrue(body(app).waitForExistence(timeout: 15), "editor body did not appear")
        return app
    }

    /// Opens the contextual `Aa` menu and picks a structure.
    private func applyStyle(_ name: String, in app: XCUIApplication) {
        let control = app.buttons["Text style"]
        XCTAssertTrue(control.waitForExistence(timeout: 8), "the Style control was not available")
        control.tap()
        let item = app.buttons[name]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "the Style menu is missing \(name)")
        item.tap()
    }

    /// Taps an edit-menu item, first raising the menu with a long press when one is needed.
    private func tapMenuItem(_ label: String, in app: XCUIApplication, longPressing field: XCUIElement?) {
        field?.press(forDuration: 1.2)
        let item = app.menuItems[label]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "edit menu item '\(label)' did not appear")
        item.tap()
    }
}
