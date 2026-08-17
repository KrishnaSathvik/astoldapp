import XCTest

/// Verifies the tap-driven navigation that screenshots can't: compose → editor → back → Home,
/// and that Calendar and Profile push and pop.
final class NavigationUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launchedApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-seedSampleNotes"]
        app.launch()
        return app
    }

    func testComposeThenBackReturnsHome() {
        let app = launchedApp()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 5), "Home should show New note")

        app.buttons["New note"].tap()
        let back = app.buttons["Back to notes"]
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Editor should show a back button")

        back.tap()
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 5), "Should return to Home")
        XCTAssertFalse(app.buttons["Back to notes"].exists, "Editor should be gone")
    }

    func testCalendarPagePushesAndPops() {
        let app = launchedApp()
        app.buttons["Open calendar"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 5), "Calendar page should push")

        app.navigationBars.buttons.element(boundBy: 0).tap() // system back
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 5), "Should return to Home")
    }

    func testProfilePagePushesAndPops() {
        let app = launchedApp()
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5), "Profile page should push")

        app.navigationBars.buttons.element(boundBy: 0).tap() // system back
        XCTAssertTrue(app.buttons["New note"].waitForExistence(timeout: 5), "Should return to Home")
    }
}
