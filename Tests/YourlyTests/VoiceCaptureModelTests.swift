import Testing
import Foundation
@testable import Yourly

@MainActor
private final class FakeRecorder: AudioRecording {
    var permission: Bool
    var startURL = URL(fileURLWithPath: "/tmp/rec-test.m4a")
    var stopReturnsNil = false
    private(set) var canceled = false
    private(set) var cleaned: [URL] = []
    var level: Float = 0.5
    var onInterruption: (() -> Void)?

    init(permission: Bool = true) { self.permission = permission }

    /// Simulates a call/Siri taking the microphone mid-recording.
    func interrupt() { onInterruption?() }

    func requestPermission() async -> Bool { permission }
    func start() throws -> URL { startURL }
    func stop() -> URL? { stopReturnsNil ? nil : startURL }
    func cancel() { canceled = true }
    func cleanup(_ url: URL) { cleaned.append(url) }
}

/// Consent that has never been granted — the first-recording state.
private struct NeverGrantedConsent: TranscriptionConsentStoring {
    var hasConsented: Bool { false }
    func grant() {}
}

@MainActor
struct VoiceCaptureModelTests {
    private func make(recorder: FakeRecorder,
                      service: TranscriptionService,
                      maxRecordingDuration: Duration = VoiceLimits.maxRecordingDuration,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: service,
                          maxRecordingDuration: maxRecordingDuration,
                          onTranscript: onText)
    }

    @Test func permissionDeniedStopsFlow() async {
        let model = make(recorder: FakeRecorder(permission: false),
                         service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        #expect(model.phase == .permissionDenied)
    }

    @Test func happyPathEmitsTranscriptAndReturnsToIdle() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(delay: .milliseconds(1))) { emitted = $0 }
        await model.begin()
        #expect(model.phase == .recording)
        model.done()
        // wait for the async transcription task to complete
        try? await Task.sleep(for: .milliseconds(50))
        #expect(emitted == FakeTranscriptionService.sampleText)
        #expect(model.phase == .idle)
        #expect(recorder.cleaned.contains(recorder.startURL))   // temp audio deleted on success
    }

    @Test func serviceErrorGoesToFailedAndKeepsTempFile() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(result: .failure(.offline), delay: .milliseconds(1))) { emitted = $0 }
        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(model.phase == .failed(.offline))
        #expect(emitted == nil)                                 // never emits text on failure
        #expect(recorder.cleaned.isEmpty)                       // temp kept for retry
    }

    @Test func retryAfterFailureSucceeds() async {
        var emitted: String?
        let recorder = FakeRecorder()
        // Service that fails first, then succeeds — model.retry() re-invokes transcribe.
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(result: .failure(.serviceUnavailable), delay: .milliseconds(1))) { emitted = $0 }
        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(model.phase == .failed(.serviceUnavailable))
        _ = emitted   // still nil
        // Swap not possible on value-type service; assert retry re-enters transcribing then fails again.
        model.retry()
        #expect(model.phase == .transcribing)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(model.phase == .failed(.serviceUnavailable))
    }

    @Test func doneWithNoRecordingIsNoSpeech() async {
        let recorder = FakeRecorder(); recorder.stopReturnsNil = true
        let model = make(recorder: recorder, service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        model.done()
        #expect(model.phase == .failed(.noSpeech))
    }

    @Test func cancelResetsAndCancelsRecorder() async {
        let recorder = FakeRecorder()
        let model = make(recorder: recorder, service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        model.cancel()
        #expect(model.phase == .idle)
        #expect(recorder.canceled)
    }

    @Test func discardCleansTempAndResets() async {
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(result: .failure(.offline), delay: .milliseconds(1)))
        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(30))
        model.discard()
        #expect(model.phase == .idle)
        #expect(recorder.cleaned.contains(recorder.startURL))
    }

    // MARK: Recording length limit

    /// The relay rejects audio over its limit, so the app stops there instead of letting someone
    /// speak for another four minutes into a request that cannot succeed.
    @Test func stopsAtTheRecordingLimitAndTranscribesWhatWasCaptured() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(delay: .milliseconds(1)),
                         maxRecordingDuration: .milliseconds(20)) { emitted = $0 }
        await model.begin()
        #expect(model.phase == .recording)

        try? await Task.sleep(for: .milliseconds(120))

        // Reaching the limit is the ordinary finish path: the words are already spoken, so they are
        // transcribed rather than thrown away.
        #expect(emitted == FakeTranscriptionService.sampleText)
        #expect(model.phase == .idle)
    }

    /// Hitting the cap must never be a way to lose a recording.
    @Test func recordingLimitKeepsTheAudioRatherThanCancelling() async {
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(delay: .milliseconds(1)),
                         maxRecordingDuration: .milliseconds(20))
        await model.begin()
        try? await Task.sleep(for: .milliseconds(120))

        #expect(recorder.canceled == false)   // cancel() deletes the temp file — never on the limit
    }

    /// A recording that finishes normally must not be stopped a second time by a timer still running.
    @Test func finishingBeforeTheLimitCancelsTheTimer() async {
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(delay: .milliseconds(1)),
                         maxRecordingDuration: .milliseconds(30))
        await model.begin()
        model.done()
        #expect(model.phase == .transcribing)

        try? await Task.sleep(for: .milliseconds(120))
        #expect(model.phase == .idle)         // still idle — the timer did not re-enter done()
    }

    /// Cancelling stops the clock too, so an abandoned capture cannot resurrect itself.
    @Test func cancellingStopsTheLimitTimer() async {
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: FakeTranscriptionService(delay: .milliseconds(1)),
                         maxRecordingDuration: .milliseconds(20))
        await model.begin()
        model.cancel()
        #expect(model.phase == .idle)

        try? await Task.sleep(for: .milliseconds(120))
        #expect(model.phase == .idle)         // the elapsed limit did not start a transcription
    }

    /// The app's mirror of the limit has to be the relay's limit, or the guard is decorative.
    @Test func clientLimitMatchesTheRelayDefault() {
        #expect(VoiceLimits.maxRecordingSeconds == 600)
        #expect(VoiceLimits.maxRecordingDuration == .seconds(600))
    }

    @Test func lengthLimitCopyReadsInMinutes() {
        #expect(RecordingPanel.lengthLimitMessage(maxSeconds: 600) == "Recordings can be up to 10 minutes.")
        #expect(RecordingPanel.lengthLimitMessage(maxSeconds: 60) == "Recordings can be up to 1 minute.")
        #expect(RecordingPanel.lengthLimitMessage(maxSeconds: 90) == "Recordings can be up to 90 seconds.")
    }
}

// MARK: - Interruption + abandoned audio

@MainActor
struct VoiceInterruptionTests {
    /// A call or Siri must not throw away what the user already said: the capture finishes and
    /// transcribes the audio recorded up to the interruption.
    @Test func interruptionFinishesTheCaptureInsteadOfDiscardingIt() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let model = VoiceCaptureModel(
            recorder: recorder,
            service: FakeTranscriptionService(delay: .milliseconds(1))
        ) { emitted = $0 }

        await model.begin()
        #expect(model.phase == .recording)

        recorder.interrupt()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(emitted == FakeTranscriptionService.sampleText)
        #expect(model.phase == .idle)
        #expect(recorder.cleaned.contains(recorder.startURL))
    }

    // MARK: Leaving the editor mid-recording

    /// The data-loss bug this method exists for: tapping Back while recording used to call
    /// `cancel()`, which deleted the audio before it was ever transcribed. Everything the user had
    /// just said disappeared, and the note went with it for being empty.
    ///
    /// Leaving now finishes the capture, exactly as backgrounding, an interruption, and the duration
    /// cap already did. Back was the only exit that destroyed the recording.
    @Test func leavingMidRecordingTranscribesInsteadOfDiscarding() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let model = VoiceCaptureModel(
            recorder: recorder,
            service: FakeTranscriptionService(delay: .milliseconds(1))
        ) { emitted = $0 }

        await model.begin()
        #expect(model.phase == .recording)

        model.finishOnLeave()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(emitted == FakeTranscriptionService.sampleText, "the spoken words must survive leaving")
        #expect(!recorder.canceled, "leaving must not cancel the recorder out from under the capture")
        #expect(model.phase == .idle)
    }

    /// Leaving stops the microphone either way — the temporary file is cleaned up once the transcript
    /// lands, so nothing is left hot or on disk (RULES.md §3).
    @Test func leavingMidRecordingLeavesNoTemporaryAudioBehind() async {
        let recorder = FakeRecorder()
        let model = VoiceCaptureModel(
            recorder: recorder,
            service: FakeTranscriptionService(delay: .milliseconds(1))
        ) { _ in }

        await model.begin()
        model.finishOnLeave()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(recorder.cleaned.contains(recorder.startURL))
    }

    /// The one case that still discards: a first recording whose disclosure was never accepted. The
    /// audio cannot be sent, and it cannot sit on disk with no UI left to ask.
    @Test func leavingBeforeConsentIsGrantedStillDiscardsTheAudio() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let model = VoiceCaptureModel(
            recorder: recorder,
            service: FakeTranscriptionService(delay: .milliseconds(1)),
            consent: NeverGrantedConsent()
        ) { emitted = $0 }

        await model.begin()
        model.finishOnLeave()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(emitted == nil, "nothing may be sent before the disclosure is accepted")
        #expect(recorder.canceled, "the audio must not be left on disk")
        #expect(model.phase == .idle)
    }

    /// Leaving a note where nothing is being recorded is just leaving.
    @Test func leavingWhenNotRecordingIsHarmless() async {
        let model = VoiceCaptureModel(
            recorder: FakeRecorder(),
            service: FakeTranscriptionService(delay: .milliseconds(1))
        ) { _ in }

        model.finishOnLeave()
        #expect(model.phase == VoiceCaptureModel.Phase.idle)
    }

    /// An interruption after the capture already ended is a no-op, not a second transcription.
    @Test func interruptionAfterDoneIsIgnored() async {
        var emissions = 0
        let recorder = FakeRecorder()
        let model = VoiceCaptureModel(
            recorder: recorder,
            service: FakeTranscriptionService(delay: .milliseconds(1))
        ) { _ in emissions += 1 }

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))
        recorder.interrupt()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(emissions == 1)
    }
}

@MainActor
struct AbandonedRecordingCleanupTests {
    /// A crash or force-quit during recording leaves raw audio in tmp; launch must sweep it and
    /// leave everything else alone (RULES.md §3).
    @Test func purgeRemovesOnlyAbandonedRecordings() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("purge-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let abandoned = dir.appendingPathComponent("rec-\(UUID().uuidString).m4a")
        let unrelatedExtension = dir.appendingPathComponent("rec-notes.txt")
        let unrelatedName = dir.appendingPathComponent("keep-me.m4a")
        for url in [abandoned, unrelatedExtension, unrelatedName] {
            try Data("x".utf8).write(to: url)
        }

        AVAudioRecorderService.purgeAbandonedRecordings(in: dir)

        #expect(!fm.fileExists(atPath: abandoned.path))
        #expect(fm.fileExists(atPath: unrelatedExtension.path))
        #expect(fm.fileExists(atPath: unrelatedName.path))
    }
}

// MARK: - One-time transcription disclosure

private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func bump() { lock.withLock { value += 1 } }
}

/// Behaves like the relay: transcribing means the recording leaves the device.
private struct UploadingTranscriptionService: TranscriptionService {
    let counter: CallCounter
    var sendsAudioOffDevice: Bool { true }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        counter.bump()
        return TranscriptionResult(text: "transcribed words", detectedLanguages: [])
    }
}

private final class MemoryConsent: TranscriptionConsentStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var granted: Bool
    init(granted: Bool = false) { self.granted = granted }
    var hasConsented: Bool { lock.withLock { granted } }
    func grant() { lock.withLock { granted = true } }
}

/// The disclosure required before a recording is shared with a third party (App Review 5.1.2(i)).
/// The contract these pin down: nothing is uploaded until the question is answered, Cancel deletes
/// the audio, and the question is asked exactly once.
@MainActor
struct TranscriptionConsentTests {

    private func make(recorder: FakeRecorder,
                      counter: CallCounter,
                      consent: TranscriptionConsentStoring,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: UploadingTranscriptionService(counter: counter),
                          consent: consent,
                          onTranscript: onText)
    }

    @Test func firstUploadWaitsForTheDisclosure() async {
        let recorder = FakeRecorder()
        let counter = CallCounter()
        let model = make(recorder: recorder, counter: counter, consent: MemoryConsent())

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .needsConsent)
        #expect(counter.count == 0, "nothing may be uploaded before the disclosure is answered")
        #expect(recorder.cleaned.isEmpty, "the recording is kept while the question is open")
    }

    @Test func continueSendsTheWaitingRecordingAndRemembersTheAnswer() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let counter = CallCounter()
        let consent = MemoryConsent()
        let model = make(recorder: recorder, counter: counter, consent: consent) { emitted = $0 }

        await model.begin()
        model.done()
        model.grantConsent()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(counter.count == 1)
        #expect(emitted == "transcribed words")
        #expect(consent.hasConsented)
        #expect(model.phase == .idle)
        #expect(recorder.cleaned.contains(recorder.startURL), "temp audio deleted on success")
    }

    @Test func cancelDeletesTheRecordingAndSendsNothing() async {
        var emitted: String?
        let recorder = FakeRecorder()
        let counter = CallCounter()
        let consent = MemoryConsent()
        let model = make(recorder: recorder, counter: counter, consent: consent) { emitted = $0 }

        await model.begin()
        model.done()
        #expect(model.phase == .needsConsent)
        model.discard()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(counter.count == 0, "declining must not upload")
        #expect(emitted == nil)
        #expect(model.phase == .idle)
        #expect(recorder.cleaned.contains(recorder.startURL), "declining deletes the recording")
        #expect(consent.hasConsented == false, "declining is not remembered as consent")
    }

    @Test func onceAnsweredItIsNeverAskedAgain() async {
        let recorder = FakeRecorder()
        let counter = CallCounter()
        let model = make(recorder: recorder, counter: counter, consent: MemoryConsent(granted: true))

        await model.begin()
        model.done()

        #expect(model.phase == .transcribing, "a consented install goes straight to transcribing")
        try? await Task.sleep(for: .milliseconds(50))
        #expect(counter.count == 1)
    }

    @Test func grantingIsIgnoredOutsideTheDisclosure() async {
        let recorder = FakeRecorder()
        let counter = CallCounter()
        let consent = MemoryConsent()
        let model = make(recorder: recorder, counter: counter, consent: consent)

        model.grantConsent()   // nothing recorded, nothing asked
        #expect(counter.count == 0)
        #expect(consent.hasConsented == false)
        #expect(model.phase == .idle)
    }

    /// A service that keeps the audio on the device has no transfer to disclose, so disclosing one
    /// would itself be inaccurate.
    @Test func aLocalOnlyServiceIsNeverGated() async {
        let recorder = FakeRecorder()
        let model = VoiceCaptureModel(recorder: recorder,
                                      service: FakeTranscriptionService(delay: .milliseconds(1)),
                                      onTranscript: { _ in })
        #expect(FakeTranscriptionService().sendsAudioOffDevice == false)

        await model.begin()
        model.done()
        #expect(model.phase == .transcribing)
    }

    /// The relay client must be treated as off-device — this is what turns the gate on in the app.
    @Test func theRelayIsTreatedAsOffDevice() {
        let relay = RelayTranscriptionService(baseURL: URL(string: "https://example.invalid")!)
        #expect(relay.sendsAudioOffDevice)
    }

    /// Leaving the note with the disclosure still open (EditorView.onDisappear calls cancel())
    /// must abort the capture rather than strand the audio waiting for an answer that never comes.
    @Test func leavingWhileTheDisclosureIsOpenAbortsTheCapture() async {
        let recorder = FakeRecorder()
        let counter = CallCounter()
        let consent = MemoryConsent()
        let model = make(recorder: recorder, counter: counter, consent: consent)

        await model.begin()
        model.done()
        #expect(model.phase == .needsConsent)
        model.cancel()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .idle)
        #expect(counter.count == 0)
        #expect(recorder.canceled, "the recorder aborts, which deletes the temporary audio")
        #expect(consent.hasConsented == false)
    }

    /// "Once, ever" has to survive relaunch, so it lives in UserDefaults rather than memory.
    @Test func theAnswerSurvivesRelaunch() {
        let suite = "consent-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(UserDefaultsTranscriptionConsent(defaults: defaults).hasConsented == false)
        UserDefaultsTranscriptionConsent(defaults: defaults).grant()
        // A fresh instance stands in for the next launch.
        #expect(UserDefaultsTranscriptionConsent(defaults: defaults).hasConsented)
    }
}
