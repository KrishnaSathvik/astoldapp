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

    func testComposeThenDoneReturnsHome() {
        let app = launchedApp()
        tap(app.buttons["New note"], "New note")
        tap(app.buttons["Done"], "editor Done button")
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 8), "Done should return to Home")
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

        tap(app.buttons["What is Yourly"], "What is Yourly row")
        XCTAssertTrue(app.navigationBars["What is Yourly"].waitForExistence(timeout: 8), "About should push")
        back(app)
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8), "Back to Profile")

        tap(app.buttons["Privacy"], "Privacy row")
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8), "Privacy should push")
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
