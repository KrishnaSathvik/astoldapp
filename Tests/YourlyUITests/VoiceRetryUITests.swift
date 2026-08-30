import XCTest

/// The retained-recording surface, driven with real taps (`docs/10-voice-v2.md` §13).
///
/// What a unit test cannot prove: that the sentence *"Your recording is still on this iPhone."*
/// actually reaches the screen, that **Retry** and **Delete Recording** are two real controls a
/// finger can hit, and that deleting leaves Home with no note in it. The capture underneath is the
/// shipping `VoiceCaptureModel` — only the microphone and the network are stood in for, through the
/// seams the spec already requires (`-voiceFakeFailure`, `-voiceFakeRetrySucceeds`).
///
/// Nothing here touches AirPods, a permission alert, real audio, or an actual phone call. Those are
/// the device pass's job, and automating them is how a suite becomes a coin toss.
final class VoiceRetryUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private static let retainedNotice = "Your recording is still on this iPhone."
    private static let recoveryTitle = "We saved a recording that couldn't be transcribed."

    private func launch(_ extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedWelcome", "YES", "-resetStore"] + extraArguments
        app.launch()
        return app
    }

    private func startQuickVoice(_ arguments: [String]) -> XCUIApplication {
        let app = launch(arguments)
        XCTAssertTrue(app.buttons["New voice note"].waitForExistence(timeout: 15), "Home did not appear")
        app.buttons["New voice note"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 10), "the capture did not start")
        app.buttons["Done"].tap()
        return app
    }

    /// The failure a dropped connection produces, and the promise it has to make.
    func testAQuickVoiceFailureKeepsTheRecordingAndSaysSo() {
        let app = startQuickVoice(["-voiceFakeFailure"])

        XCTAssertTrue(app.staticTexts[Self.retainedNotice].waitForExistence(timeout: 10),
                      "the failure never told the user the recording survived")
        XCTAssertTrue(app.buttons["Retry"].exists, "Retry is missing")
        XCTAssertTrue(app.buttons["Delete Recording"].exists, "Delete Recording is missing")
        // The failure stays on the capture surface — a Quick Voice capture has no note to go back to.
        XCTAssertFalse(app.buttons["New note"].isHittable, "the failure bounced back to Home")
    }

    /// Deleting is deleting: no transcript, no note, and no way back to the recording.
    func testDeleteRecordingReturnsToHomeWithNoNote() {
        let app = startQuickVoice(["-voiceFakeFailure"])
        XCTAssertTrue(app.buttons["Delete Recording"].waitForExistence(timeout: 10))
        app.buttons["Delete Recording"].tap()

        XCTAssertTrue(app.buttons["New voice note"].waitForExistence(timeout: 10),
                      "Delete Recording did not return to Home")
        XCTAssertFalse(app.buttons["Retry"].exists, "Retry outlived the recording it retried")
        XCTAssertEqual(app.cells.count, 0, "a failed capture left a note behind")
    }

    /// One affordance, used: the same audio goes again, and this time it comes back as a note.
    func testRetryTurnsTheSameRecordingIntoANote() {
        let app = startQuickVoice(["-voiceFakeRetrySucceeds"])
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 10))
        app.buttons["Retry"].tap()

        let transcript = app.textViews.containing(
            NSPredicate(format: "value CONTAINS %@", "This is what the recording said.")
        ).firstMatch
        XCTAssertTrue(transcript.waitForExistence(timeout: 15),
                      "the retried recording never became a note")
    }

    /// A recording that outlived its capture is offered back once, on one surface, with two controls.
    func testARecordingThatOutlivedItsCaptureIsOfferedBackOnLaunch() {
        let app = launch(["-seedRetainedRecording", "-voiceFakeSuccess"])

        XCTAssertTrue(app.staticTexts[Self.recoveryTitle].waitForExistence(timeout: 15),
                      "the kept recording was never offered back")
        XCTAssertTrue(app.buttons["Retry"].exists)
        XCTAssertTrue(app.buttons["Delete Recording"].exists)
        // One recording, two controls — never a list of them.
        XCTAssertEqual(app.buttons.matching(identifier: "Retry").count, 1)
    }

    /// Retrying it is what the whole phase is for: the words become an ordinary note.
    func testRetryingARecoveredRecordingCreatesANote() {
        let app = launch(["-seedRetainedRecording", "-voiceFakeSuccess"])
        XCTAssertTrue(app.buttons["Retry"].waitForExistence(timeout: 15))
        app.buttons["Retry"].tap()

        let transcript = app.textViews.containing(
            NSPredicate(format: "value CONTAINS %@", "This is what the recording said.")
        ).firstMatch
        XCTAssertTrue(transcript.waitForExistence(timeout: 15),
                      "the recovered recording never became a note")
    }

    func testDeletingARecoveredRecordingLeavesHomeEmpty() {
        let app = launch(["-seedRetainedRecording", "-voiceFakeSuccess"])
        XCTAssertTrue(app.buttons["Delete Recording"].waitForExistence(timeout: 15))
        app.buttons["Delete Recording"].tap()

        XCTAssertTrue(app.buttons["New voice note"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts[Self.recoveryTitle].exists,
                       "the deleted recording was still being offered")
        XCTAssertEqual(app.cells.count, 0)
    }

    /// **Back is navigation, not Delete Recording.** Leaving a note mid-failure keeps the recording,
    /// and Home offers it back straight away.
    func testLeavingANoteMidFailureKeepsTheRecording() {
        // Opened *through Home* rather than by the direct-to-editor debug route, because Home is
        // where Back lands and where the recovery offer has to appear.
        let app = launch(["-seedVoiceDemo", "-autoStartVoice", "-voiceFakeFailure"])
        let row = app.staticTexts["Alaska trip idea"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Home did not show the seeded note")
        row.tap()

        XCTAssertTrue(app.staticTexts[Self.retainedNotice].waitForExistence(timeout: 20),
                      "the in-note failure never appeared")

        app.navigationBars.buttons.element(boundBy: 0).tap()   // Back

        XCTAssertTrue(app.staticTexts[Self.recoveryTitle].waitForExistence(timeout: 10),
                      "Back threw away a recording the user could still retry")
        XCTAssertTrue(app.buttons["Retry"].exists)
    }

    /// The last durability hole: leaving the note while the upload is still in flight. The words are
    /// already spoken and committed, so navigating away keeps them.
    func testLeavingANoteMidTranscriptionKeepsTheRecording() {
        let app = launch(["-seedVoiceDemo", "-autoStartVoice", "-voiceFakeSlow"])
        let row = app.staticTexts["Alaska trip idea"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Home did not show the seeded note")
        row.tap()

        // `-autoStartVoice` stops the recording a moment in, and `-voiceFakeSlow` holds the upload
        // open long enough to leave during it. Waited for by its own accessibility label — matched on
        // any element, because the indicator combines its spinner and its words into one.
        let transcribing = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Transcribing")).firstMatch
        XCTAssertTrue(transcribing.waitForExistence(timeout: 25), "the upload never started")

        app.navigationBars.buttons.element(boundBy: 0).tap()   // Back, mid-upload

        XCTAssertTrue(app.staticTexts[Self.recoveryTitle].waitForExistence(timeout: 20),
                      "Back during transcription threw the recording away")
        XCTAssertTrue(app.buttons["Retry"].exists)
        // The transcript belongs to an editing session that is gone, so it will arrive as a new note.
        XCTAssertTrue(app.staticTexts["This recording will be saved as a new note."].exists,
                      "the recovery surface did not say where the transcript would land")
    }

    /// An in-note failure stays with the note: the panel keeps it, and the note is untouched.
    func testAnInNoteFailureKeepsTheRecordingWithoutTouchingTheNote() {
        let app = launch(["-seedVoiceDemo", "-openSeededNote", "-autoStartVoice", "-voiceFakeFailure"])

        XCTAssertTrue(app.staticTexts[Self.retainedNotice].waitForExistence(timeout: 20),
                      "the panel never told the user the recording survived")
        XCTAssertTrue(app.buttons["Retry"].exists)
        XCTAssertTrue(app.buttons["Delete Recording"].exists)

        let body = app.textViews.firstMatch
        XCTAssertTrue(body.exists, "the note went away")
        let text = (body.value as? String) ?? ""
        XCTAssertTrue(text.contains("Alaska"), "the failed capture changed the note")
    }
}
