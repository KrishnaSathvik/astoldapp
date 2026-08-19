import XCTest

/// Verifies the tap-driven navigation that screenshots can't: compose → editor → back → Home,
/// Calendar / Profile / Theme push and pop. Each interaction waits for its target to be hittable
/// first, so the flow is resilient to launch/animation timing.
final class NavigationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore", "-seedSampleNotes"]
        app.launch()
        // Home is ready when the New note button exists.
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    @discardableResult
    private func tap(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            XCTFail("missing element: \(message)")
            return false
        }
        element.tap()
        return true
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
    }

    func testComposeThenBackReturnsHome() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Back to notes"], "editor back button")
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 8), "Should return to Home")
        XCTAssertFalse(app.buttons["Back to notes"].exists, "Editor should be gone")
    }

    /// A new note is a capture intent: the editor opens with the keyboard already up.
    func testNewNoteOpensWithTheKeyboard() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8),
                      "A new note should open ready to type")
    }

    /// An existing note is a reading intent: nothing takes first responder, so no keyboard.
    func testExistingNoteOpensForReadingWithoutTheKeyboard() {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "seeded note should exist")
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "Editor should open")
        XCTAssertFalse(app.keyboards.element.waitForExistence(timeout: 3),
                       "Opening an existing note must not raise the keyboard")
        // No completion control while reading — autosave is the only save (RULES.md §4).
        XCTAssertFalse(app.buttons["Dismiss keyboard"].exists,
                       "Done should not be offered when there is nothing to dismiss")
    }

    /// Tapping the body starts editing, and Done puts the keyboard away without leaving the note.
    func testTappingBodyStartsEditingAndDoneDismissesTheKeyboard() {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8))
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8))

        app.textViews.firstMatch.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8),
                      "Tapping the body should start editing")

        tap(app.buttons["Dismiss keyboard"], "editor Done button")
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 8),
                      "Done should dismiss the keyboard")
        XCTAssertTrue(app.buttons["Back to notes"].exists,
                      "Done must not navigate away — it only dismisses the keyboard")
    }

    func testSwipeToDeleteRemovesNote() {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "seeded note should exist")
        note.swipeLeft()
        tap(app.buttons["Delete"], "revealed Delete button")
        XCTAssertTrue(note.waitForNonExistence(timeout: 8), "note should be removed after delete")
    }

    func testCalendarPagePushesAndPops() {
        let app = launchedApp()
        tap(app.buttons["Open calendar"], "calendar button")
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 8), "Calendar should push")
        back(app)
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 8), "Should return to Home")
    }

    func testProfilePagePushesAndPops() {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8), "Profile should push")
        back(app)
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 8), "Should return to Home")
    }

    func testProfileAboutAndPrivacyPushAndPop() {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))

        tap(app.buttons["What is As Told"], "What is As Told row")
        XCTAssertTrue(app.navigationBars["What is As Told"].waitForExistence(timeout: 8), "About should push")
        back(app)
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8), "Back to Profile")

        tap(app.buttons["Privacy"], "Privacy row")
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8), "Privacy should push")

        // App Review 5.1.1(i) wants the policy reachable from inside the app, and the permanent
        // voice explanation has to be findable without waiting for the one-time disclosure.
        XCTAssertTrue(app.buttons["Privacy Policy"].waitForExistence(timeout: 8),
                      "Privacy should link out to the hosted policy")

        tap(app.buttons["Voice Transcription"], "Voice Transcription row")
        XCTAssertTrue(app.navigationBars["Voice Transcription"].waitForExistence(timeout: 8),
                      "Voice Transcription detail should push")
        back(app)
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8), "Back to Privacy")
    }

    /// Apple's automated audit, scoped to the types we enforce: hit-region size + sufficient element
    /// descriptions. (Contrast/Dynamic-Type are logged separately — the muted "Quiet Editorial"
    /// palette is a reviewed design choice; see docs/03-design-system.md §14.)
    private static let enforcedAudits: XCUIAccessibilityAuditType = [.hitRegion, .sufficientElementDescription]

    @MainActor func testHomeAccessibilityAudit() throws {
        let app = launchedApp()
        try app.performAccessibilityAudit(for: Self.enforcedAudits)
    }

    @MainActor func testProfileAccessibilityAudit() throws {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))
        try app.performAccessibilityAudit(for: Self.enforcedAudits)
    }

    /// The editor in its reading state — the screen a user spends the most time looking at.
    @MainActor func testEditorAccessibilityAudit() throws {
        let app = launchedApp()
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8))
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8))
        try app.performAccessibilityAudit(for: Self.enforcedAudits)
    }

    func testThemePickerOpensAndSelectsDark() {
        let app = launchedApp()
        tap(app.buttons["Profile"], "profile button")
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))

        tap(app.staticTexts["Theme"], "Theme row")
        XCTAssertTrue(app.navigationBars["Theme"].waitForExistence(timeout: 8), "Theme screen should push")

        tap(app.staticTexts["Dark"], "Dark option")
        back(app)
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8), "Back to Profile")
    }
}

/// The editor's overflow menu. It exists for one reason: there must be a way to delete the note you
/// are currently looking at, and it must take the same reversible path as a swipe on Home.
final class EditorOverflowUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore", "-seedSampleNotes"]
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    private func openSeededNote(_ app: XCUIApplication) {
        let note = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
            .firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 8), "seeded note should exist")
        note.tap()
        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "editor should open")
    }

    func testOverflowHoldsOnlyDelete() {
        let app = launchedApp()
        openSeededNote(app)

        app.buttons["More actions"].tap()
        XCTAssertTrue(app.buttons["Delete Note"].waitForExistence(timeout: 8),
                      "the overflow should offer Delete Note")
        // Guard against the menu becoming a junk drawer (RULES.md §7).
        for forbidden in ["Share", "Export", "Duplicate", "Format", "Word Count", "Pin"] {
            XCTAssertFalse(app.buttons[forbidden].exists, "\(forbidden) must not be in the overflow")
        }
    }

    func testDeletingFromTheEditorReturnsHomeAndIsUndoable() {
        let app = launchedApp()
        openSeededNote(app)

        app.buttons["More actions"].tap()
        XCTAssertTrue(app.buttons["Delete Note"].waitForExistence(timeout: 8))
        app.buttons["Delete Note"].tap()

        // Same reversible path as a swipe: the Undo banner is waiting on Home. Asserted first —
        // the banner is deliberately short-lived, and every XCUI query costs a snapshot.
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 8), "Undo should be offered on Home")

        let deleted = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Alaska trip idea"))
        XCTAssertFalse(deleted.firstMatch.exists, "note should be gone")

        undo.tap()
        XCTAssertTrue(deleted.firstMatch.waitForExistence(timeout: 8), "Undo should restore the note")
    }
}
