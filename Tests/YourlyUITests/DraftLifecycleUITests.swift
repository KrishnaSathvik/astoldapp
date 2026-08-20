import XCTest

/// A draft the editor still owns must survive a temporary scene transition.
///
/// Regression cover for a silent data-loss bug found on device (2026-08-19): the first voice note of
/// a fresh install showed its transcript in the editor and was then missing from the timeline. The
/// microphone permission alert resigns the app active, the editor flushed while the note was still
/// empty, and the flush *discarded and committed* the deletion — after which nothing written into
/// that note could be saved. Typing hit the same bug; voice only exposed it first, because the
/// permission alert makes it happen on every first run.
///
/// Driven by typing rather than voice so it needs no relay: the defect is in the draft lifecycle,
/// not the voice path. The voice half is covered by `EditorModelTests` and
/// `VoiceDraftPersistenceTests`.
final class DraftLifecycleUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testContentWrittenAfterAnInterruptionSurvivesLeaving() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetStore", "-exposeSourceForTests", "-hasCompletedWelcome", "YES"]
        app.launch()

        let compose = app.buttons["New note"]
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "Home did not appear")
        compose.tap()

        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15), "editor body did not appear")

        // The scene transition a permission alert (or Control Center, or a call) causes, while the
        // draft is still empty.
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2.0)
        app.activate()
        Thread.sleep(forTimeInterval: 2.0)

        field.tap()
        field.typeText("written after the interruption")

        let back = app.buttons["Back to notes"]
        XCTAssertTrue(back.waitForExistence(timeout: 10), "Back button missing")
        back.tap()
        XCTAssertTrue(compose.waitForExistence(timeout: 15), "did not return to Home")

        let row = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "written after the interruption"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8),
                      "the note was lost by a temporary scene transition")
    }
}
