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

/// The calendar reaches a day's notes in place: tap a day, its notes appear under the grid, tap one
/// to open it — and Back comes home to the calendar, not to Home.
final class CalendarDayNotesUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore", "-seedSampleNotes"]
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    private func openCalendar(_ app: XCUIApplication) {
        app.buttons["Open calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 8), "Calendar should push")
    }

    private static func dayIdentifier(daysAgo: Int) -> String {
        let cal = Calendar.current
        let date = cal.date(byAdding: .day, value: -daysAgo, to: .now)!
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "day-%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func note(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch
    }

    /// The core of the change: a day's notes are listed on the calendar, not on another screen.
    func testTappingADayListsThatDaysNotesOnTheCalendar() {
        let app = launchedApp()
        openCalendar(app)

        // Two days ago the seed has "Work ideas"; yesterday it has "Random thoughts at night".
        app.buttons[Self.dayIdentifier(daysAgo: 2)].tap()
        XCTAssertTrue(note(app, "Work ideas").waitForExistence(timeout: 8),
                      "that day's note should be listed under the grid")
        XCTAssertFalse(note(app, "Random thoughts at night").exists,
                       "another day's note must not be listed")
        XCTAssertTrue(app.navigationBars["Calendar"].exists, "still on the calendar — no navigation")

        app.buttons[Self.dayIdentifier(daysAgo: 1)].tap()
        XCTAssertTrue(note(app, "Random thoughts at night").waitForExistence(timeout: 8),
                      "selecting another day swaps the list")
        XCTAssertFalse(note(app, "Work ideas").exists)
    }

    /// Opening a note from the calendar and coming back must land on the calendar, with the same
    /// day still selected — never on Home.
    func testOpeningANoteFromTheCalendarReturnsToTheCalendar() {
        let app = launchedApp()
        openCalendar(app)

        app.buttons[Self.dayIdentifier(daysAgo: 2)].tap()
        let row = note(app, "Work ideas")
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()

        XCTAssertTrue(app.buttons["Back to notes"].waitForExistence(timeout: 8), "editor should open")
        app.buttons["Back to notes"].tap()

        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 8),
                      "Back should return to the calendar, not Home")
        XCTAssertTrue(note(app, "Work ideas").waitForExistence(timeout: 8),
                      "the same day should still be selected")
        XCTAssertFalse(app.buttons["New note"].exists, "should not have fallen through to Home")
    }

    /// A day with nothing on it says so, in place.
    func testADayWithNoNotesSaysSoInPlace() {
        let app = launchedApp()
        openCalendar(app)

        app.buttons[Self.dayIdentifier(daysAgo: 4)].tap()   // the seed stops at 2 days ago
        XCTAssertTrue(app.staticTexts["Nothing written on this day."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["Calendar"].exists, "still on the calendar")
    }

    /// Deleting from a note opened via the calendar is offered and reversible, right here.
    func testDeletingANoteOpenedFromTheCalendarIsUndoableOnTheCalendar() {
        let app = launchedApp()
        openCalendar(app)

        app.buttons[Self.dayIdentifier(daysAgo: 2)].tap()
        let row = note(app, "Work ideas")
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()

        XCTAssertTrue(app.buttons["More actions"].waitForExistence(timeout: 8))
        app.buttons["More actions"].tap()
        XCTAssertTrue(app.buttons["Delete Note"].waitForExistence(timeout: 8))
        app.buttons["Delete Note"].tap()

        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 8), "Undo should be offered on the calendar")
        XCTAssertTrue(app.navigationBars["Calendar"].exists, "deletion returns to the calendar")
        XCTAssertFalse(note(app, "Work ideas").exists, "the row should be gone")

        undo.tap()
        XCTAssertTrue(note(app, "Work ideas").waitForExistence(timeout: 8), "Undo restores it")
    }
}

/// Home's chronological identity. The defect these lock down: `Today` was printed by the day
/// grouping rather than by Home itself, so a day with nothing written on it opened on `Yesterday`.
final class TimelineHeaderUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp(seed: String? = "-seedSampleNotes") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore"]
        if let seed { app.launchArguments.append(seed) }
        app.launch()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 15), "Home did not appear")
        return app
    }

    private static func todayLabel() -> String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy"
        return df.string(from: .now).uppercased()
    }

    func testHomeAnchorsOnTodayAboveTheGroups() {
        let app = launchedApp()
        XCTAssertTrue(app.staticTexts[Self.todayLabel()].waitForExistence(timeout: 8),
                      "Home should show the current date")
        XCTAssertTrue(app.staticTexts["Today"].exists, "Today should anchor Home")
        XCTAssertTrue(app.staticTexts["Yesterday"].exists, "older groups still have their headers")
    }

    /// With nothing written today, `Today` must still be the first heading — never `Yesterday`.
    func testTodayStillAnchorsHomeWithNoNotesToday() {
        let app = launchedApp(seed: nil)
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8),
                      "Today should anchor Home even with no notes")
    }

    /// The regression that matters: notes exist, but none of them are from today. Home must still
    /// open on `Today`, with the older groups beneath it.
    func testTodayAnchorsHomeWhenEveryNoteIsOlder() {
        let app = launchedApp(seed: "-seedOlderNotesOnly")
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 8),
                      "Today should anchor Home even when nothing was written today")
        XCTAssertTrue(app.staticTexts[Self.todayLabel()].exists, "current date still leads Home")
        XCTAssertFalse(app.staticTexts["Yesterday"].exists,
                       "the seed is a week old, so Yesterday should not appear at all")
    }
}
