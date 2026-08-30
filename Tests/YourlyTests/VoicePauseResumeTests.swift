import Testing
import Foundation
@testable import Yourly

/// Pause / resume, and the explicit states around them (`docs/10-voice-v2.md` §4, §5).
///
/// §4 is specific about the shape: `recording` and `paused` MUST be distinguishable **states**, not
/// `recording` plus an `isPaused` flag — "the flag version is how a paused recorder ends up still
/// counting time". So these tests assert on the phase, and on the one thing the flag version always
/// gets wrong: that five minutes of thinking between two sentences is not five minutes of voice.
///
/// Every one of them runs without a microphone, a network, or a view, which §4 requires.
@MainActor
private final class PausableRecorder: AudioRecording {
    var permission: Bool
    /// How long the permission prompt takes to answer, so `requestingPermission` can be observed.
    var permissionDelay: Duration = .zero
    var startURL = URL(fileURLWithPath: "/tmp/rec-pause-test.m4a")
    var level: Float = 0.5
    var onInterruption: (() -> Void)?

    private(set) var canceled = false
    private(set) var cleaned: [URL] = []
    private(set) var pauses = 0
    private(set) var resumes = 0
    private(set) var stops = 0
    /// Every start/pause/resume/stop in order — a single file is only single if nothing restarts it.
    private(set) var log: [String] = []

    init(permission: Bool = true) { self.permission = permission }

    func requestPermission() async -> Bool {
        if permissionDelay > .zero { try? await Task.sleep(for: permissionDelay) }
        return permission
    }
    func start() throws -> URL { log.append("start"); return startURL }
    func pause() { pauses += 1; log.append("pause") }
    func resume() { resumes += 1; log.append("resume") }
    func stop() -> URL? { stops += 1; log.append("stop"); return startURL }
    func cancel() { canceled = true; log.append("cancel") }
    func cleanup(_ url: URL) { cleaned.append(url) }
}

@MainActor
struct VoicePauseResumeTests {

    private func make(_ recorder: PausableRecorder,
                      maxRecordingDuration: Duration = VoiceLimits.maxRecordingDuration,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: FakeTranscriptionService(delay: .milliseconds(1)),
                          maxRecordingDuration: maxRecordingDuration,
                          onTranscript: onText)
    }

    // MARK: The states are states

    @Test func askingForPermissionIsAStateOfItsOwn() async {
        let recorder = PausableRecorder()
        recorder.permissionDelay = .milliseconds(120)
        let model = make(recorder)

        let begun = Task { await model.begin() }
        try? await Task.sleep(for: .milliseconds(40))
        #expect(model.phase == .requestingPermission)
        await begun.value
        #expect(model.phase == .recording)
    }

    @Test func pausingIsADistinctStateNotAFlag() async {
        let recorder = PausableRecorder()
        let model = make(recorder)
        await model.begin()

        model.pause()
        #expect(model.phase == .paused)
        #expect(recorder.pauses == 1)

        model.resume()
        #expect(model.phase == .recording)
        #expect(recorder.resumes == 1)
    }

    @Test func pausingKeepsOneContinuousRecording() async {
        // §5: pause/resume MUST produce a single continuous file. Restarting the recorder would make
        // two, and the relay measures the container it is given.
        let recorder = PausableRecorder()
        let model = make(recorder)
        await model.begin()
        model.pause()
        model.resume()
        model.pause()
        model.resume()

        #expect(recorder.log == ["start", "pause", "resume", "pause", "resume"])
        #expect(recorder.canceled == false)
        #expect(recorder.stops == 0)
    }

    // MARK: Transitions that must do nothing

    @Test func pausingWhenNotRecordingDoesNothing() async {
        let recorder = PausableRecorder()
        let model = make(recorder)
        model.pause()
        #expect(model.phase == .idle)
        #expect(recorder.pauses == 0)

        await model.begin()
        model.pause()
        model.pause()
        #expect(recorder.pauses == 1, "a second pause reached the recorder")
    }

    @Test func resumingWhenNotPausedDoesNothing() async {
        let recorder = PausableRecorder()
        let model = make(recorder)
        await model.begin()
        model.resume()
        #expect(model.phase == .recording)
        #expect(recorder.resumes == 0)
    }

    // MARK: Finishing from either state

    @Test func doneWorksWhilePaused() async {
        // §5's layout keeps **Done** available in the paused state: somebody who paused and then
        // decided they were finished must not have to resume in order to stop.
        var emitted: String?
        let recorder = PausableRecorder()
        let model = make(recorder) { emitted = $0 }
        await model.begin()
        model.pause()
        model.done()
        try? await Task.sleep(for: .milliseconds(60))

        #expect(emitted == FakeTranscriptionService.sampleText)
        #expect(recorder.stops == 1)
    }

    @Test func leavingWhilePausedFinishesRatherThanDiscards() async {
        // The same rule Back already follows while recording: the words are already spoken.
        var emitted: String?
        let recorder = PausableRecorder()
        let model = make(recorder) { emitted = $0 }
        await model.begin()
        model.pause()
        model.finishOnLeave()
        try? await Task.sleep(for: .milliseconds(60))

        #expect(emitted == FakeTranscriptionService.sampleText)
        #expect(recorder.canceled == false)
    }

    @Test func cancellingWhilePausedDiscardsTheRecording() async {
        let recorder = PausableRecorder()
        let model = make(recorder)
        await model.begin()
        model.pause()
        model.cancel()

        #expect(model.phase == .idle)
        #expect(recorder.canceled)
    }

    // MARK: The cap sums recorded audio, not wall-clock time

    /// The defect this whole slice exists to prevent: a paused recorder that keeps counting.
    @Test func thePauseDoesNotSpendTheRecordingCap() async {
        let recorder = PausableRecorder()
        let model = make(recorder, maxRecordingDuration: .milliseconds(200))
        await model.begin()

        try? await Task.sleep(for: .milliseconds(40))
        model.pause()
        // Far longer than the cap — but none of it is voice.
        try? await Task.sleep(for: .milliseconds(400))

        #expect(model.phase == .paused, "the cap fired on wall-clock time while paused")
        #expect(recorder.stops == 0)

        model.resume()
        #expect(model.phase == .recording)
    }

    @Test func theCapStillFiresOnTheSummedRecordedAudio() async {
        let recorder = PausableRecorder()
        let model = make(recorder, maxRecordingDuration: .milliseconds(200))
        await model.begin()

        try? await Task.sleep(for: .milliseconds(120))
        model.pause()
        try? await Task.sleep(for: .milliseconds(300))
        model.resume()
        // 120ms banked + 120ms more = past the 200ms cap.
        try? await Task.sleep(for: .milliseconds(200))

        #expect(recorder.stops == 1, "the summed audio never reached the cap")
        #expect(model.phase != .recording && model.phase != .paused)
    }

    // MARK: What the timer shows

    @Test func theElapsedTimeFreezesWhilePaused() async {
        let recorder = PausableRecorder()
        let model = make(recorder)
        await model.begin()
        try? await Task.sleep(for: .milliseconds(60))
        model.pause()

        let atPause = model.elapsedRecording
        try? await Task.sleep(for: .milliseconds(200))
        #expect(model.elapsedRecording == atPause, "the timer counted the pause")
    }

    @Test func theElapsedTimeResumesFromWhereItStopped() async {
        let recorder = PausableRecorder()
        let model = make(recorder)
        await model.begin()
        try? await Task.sleep(for: .milliseconds(60))
        model.pause()
        let atPause = model.elapsedRecording
        try? await Task.sleep(for: .milliseconds(150))
        model.resume()
        try? await Task.sleep(for: .milliseconds(60))

        #expect(model.elapsedRecording > atPause)
        // Well under the wall-clock span, which was ~270ms.
        #expect(model.elapsedRecording < .milliseconds(200))
    }
}
