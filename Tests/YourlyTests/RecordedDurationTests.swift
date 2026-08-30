import Testing
import Foundation
@testable import Yourly

/// How much audio a capture has actually recorded, across any number of pauses.
///
/// The rule this exists to enforce (`docs/10-voice-v2.md` §5): **the timer measures recorded audio,
/// never wall-clock time.** A recorder that counts the pause is a recorder that reaches the five-minute
/// cap without five minutes of speech in it, and §4 names the shape that causes it — `recording` plus an
/// `isPaused` flag. This is the arithmetic kept out of the model so it can be checked without a
/// microphone, a clock that really ticks, or a view.
@MainActor
struct RecordedDurationTests {

    private let start = ContinuousClock().now

    /// The spec's own worked example: 2:30, five minutes of pause, 2:30 → five minutes of voice.
    @Test func pausedTimeIsNotRecordedTime() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        recorded.pause(at: start + .seconds(150))
        recorded.resume(at: start + .seconds(450))

        #expect(recorded.elapsed(at: start + .seconds(600)) == .seconds(300))
    }

    @Test func nothingIsRecordedBeforeItStarts() {
        let recorded = RecordedDuration()
        #expect(recorded.elapsed(at: start + .seconds(90)) == .zero)
        #expect(recorded.isRunning == false)
    }

    @Test func aRunningSegmentCountsAsItGoes() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        #expect(recorded.isRunning)
        #expect(recorded.elapsed(at: start + .seconds(30)) == .seconds(30))
        #expect(recorded.elapsed(at: start + .seconds(60)) == .seconds(60))
    }

    @Test func aPausedCaptureStopsCounting() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        recorded.pause(at: start + .seconds(40))

        #expect(recorded.isRunning == false)
        #expect(recorded.elapsed(at: start + .seconds(40)) == .seconds(40))
        #expect(recorded.elapsed(at: start + .seconds(3_600)) == .seconds(40),
                "an hour of pause added an hour of voice")
    }

    @Test func manyPausesSumToTheAudioThatWasActuallySpoken() {
        var recorded = RecordedDuration()
        var now = start
        recorded.start(at: now)
        for _ in 0..<5 {
            now = now + .seconds(20)
            recorded.pause(at: now)
            now = now + .seconds(300)      // a long think between sentences
            recorded.resume(at: now)
        }
        now = now + .seconds(20)
        #expect(recorded.elapsed(at: now) == .seconds(120))
    }

    // MARK: Transitions that must not corrupt the count

    @Test func pausingTwiceDoesNotBankTheSameSegmentTwice() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        recorded.pause(at: start + .seconds(30))
        recorded.pause(at: start + .seconds(90))

        #expect(recorded.elapsed(at: start + .seconds(120)) == .seconds(30))
    }

    @Test func resumingWhileAlreadyRunningDoesNotRestartTheSegment() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        recorded.resume(at: start + .seconds(30))

        #expect(recorded.elapsed(at: start + .seconds(60)) == .seconds(60))
    }

    @Test func aClockThatGoesBackwardsNeverSubtractsRecordedAudio() {
        // `ContinuousClock` does not go backwards, but the arithmetic must not be the thing that
        // decides that — a negative segment would hand the cap more room than the user has spoken.
        var recorded = RecordedDuration()
        recorded.start(at: start + .seconds(60))
        #expect(recorded.elapsed(at: start) == .zero)
    }

    // MARK: What is left before the cap

    @Test func remainingCountsDownAgainstTheCap() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        #expect(recorded.remaining(of: .seconds(300), at: start + .seconds(60)) == .seconds(240))
    }

    @Test func remainingIsFrozenWhilePaused() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        recorded.pause(at: start + .seconds(60))

        #expect(recorded.remaining(of: .seconds(300), at: start + .seconds(3_600)) == .seconds(240))
    }

    @Test func remainingNeverGoesBelowZero() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        #expect(recorded.remaining(of: .seconds(300), at: start + .seconds(600)) == .zero)
    }

    @Test func theCapIsReachedOnTheSummedAudioNotTheWallClock() {
        var recorded = RecordedDuration()
        recorded.start(at: start)
        recorded.pause(at: start + .seconds(150))
        recorded.resume(at: start + .seconds(3_000))       // ten minutes of pause

        #expect(recorded.hasReached(.seconds(300), at: start + .seconds(3_100)) == false,
                "the cap fired on wall-clock time")
        #expect(recorded.hasReached(.seconds(300), at: start + .seconds(3_150)))
    }
}
