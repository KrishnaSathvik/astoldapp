import Testing
import Foundation
import AVFoundation
import SwiftData
@testable import Yourly

/// Voice V2 Phase 2B — a finished recording is never casually lost (`docs/10-voice-v2.md` §13,
/// `RULES.md` §2).
///
/// The failure this whole file exists to make impossible:
///
///     spoke something useful → network / call / route / background event → the recording is gone
///
/// Every test here runs without a microphone, a network, a real clock, or a view: the retention
/// decision, the 24-hour lifetime, and the route/interruption policy are all pure enough to check
/// directly, which is what `docs/10-voice-v2.md` §4 requires of every transition.

// MARK: - Which failures may keep a recording

struct VoiceRetryabilityTests {

    /// Retained audio exists for one reason: sending *this same file* again could plausibly work.
    @Test func transientFailuresAreRetryable() {
        #expect(TranscriptionError.offline.isRetryableVoiceFailure)
        #expect(TranscriptionError.timedOut.isRetryableVoiceFailure)
        #expect(TranscriptionError.rateLimited.isRetryableVoiceFailure)
        #expect(TranscriptionError.serviceUnavailable.isRetryableVoiceFailure)
    }

    /// A garbled or unreadable answer is the one ambiguous case, and it is resolved in the
    /// recording's favour: the same upload may well come back readable, and the cost of being wrong
    /// is one tap that fails, against destroying audio the user already spoke.
    @Test func anUnreadableAnswerIsRetryable() {
        #expect(TranscriptionError.invalidResponse.isRetryableVoiceFailure)
    }

    /// Retrying these cannot succeed without something *else* changing, so keeping the audio would
    /// only be As Told quietly accumulating recordings (`docs/10-voice-v2.md` §13).
    @Test func failuresThatCannotSucceedOnTheSameAudioAreNotRetryable() {
        #expect(!TranscriptionError.noSpeech.isRetryableVoiceFailure)
        #expect(!TranscriptionError.monthlyLimitReached(resetsAt: nil).isRetryableVoiceFailure)
        #expect(!TranscriptionError.recordingTooLong(maxSeconds: 300).isRetryableVoiceFailure)
        #expect(!TranscriptionError.requestTooLarge.isRetryableVoiceFailure)
        #expect(!TranscriptionError.microphonePermissionDenied.isRetryableVoiceFailure)
        #expect(!TranscriptionError.cancelled.isRetryableVoiceFailure)
    }
}

// MARK: - The 24-hour lifetime

struct RetainedVoiceRecordingTests {

    private let url = URL(fileURLWithPath: "/tmp/rec-retained.m4a")

    @Test func theLifetimeIsTwentyFourHoursAndLivesBesideTheOtherVoiceLimits() {
        #expect(VoiceLimits.retryLifetimeSeconds == 24 * 60 * 60)
        #expect(VoiceLimits.retryLifetime == .seconds(24 * 60 * 60))
    }

    @Test func expiryIsTwentyFourHoursAfterRetention() {
        let at = Date(timeIntervalSinceReferenceDate: 1_000)
        let retained = RetainedVoiceRecording(url: url, retainedAt: at)
        #expect(retained.expiresAt == at.addingTimeInterval(24 * 60 * 60))
    }

    @Test func aFreshRecordingHasNotExpired() {
        let at = Date(timeIntervalSinceReferenceDate: 1_000)
        let retained = RetainedVoiceRecording(url: url, retainedAt: at)
        #expect(!retained.hasExpired(at: at))
        #expect(!retained.hasExpired(at: at.addingTimeInterval(23 * 60 * 60)))
    }

    /// The boundary is defined rather than left to whichever comparison was written first: at
    /// exactly 24 hours the recording is over, not one instant short of it.
    @Test func theBoundaryItselfCountsAsExpired() {
        let at = Date(timeIntervalSinceReferenceDate: 1_000)
        let retained = RetainedVoiceRecording(url: url, retainedAt: at)
        #expect(retained.hasExpired(at: at.addingTimeInterval(24 * 60 * 60)))
        #expect(retained.hasExpired(at: at.addingTimeInterval(24 * 60 * 60 + 1)))
    }

    /// A clock that has moved backwards (time zone edit, NTP correction) must not be read as a
    /// recording from the future and must not be read as an expiry either — it is simply not old
    /// yet. Same convention as `RecordedDuration`, where a negative span floors at zero.
    @Test func aClockThatWentBackwardsDoesNotExpireTheRecording() {
        let at = Date(timeIntervalSinceReferenceDate: 100_000)
        let retained = RetainedVoiceRecording(url: url, retainedAt: at)
        #expect(!retained.hasExpired(at: at.addingTimeInterval(-60 * 60)))
        #expect(retained.age(at: at.addingTimeInterval(-60 * 60)) == 0)
    }
}

// MARK: - Route changes

/// The policy for a microphone that disappears mid-thought (`docs/10-voice-v2.md` §14).
///
/// Conservative on purpose: audio already captured survives every route event, and a recorder that
/// cannot be proven to still be listening is finished rather than left drawing a live waveform over
/// a dead input.
struct AudioRouteChangeTests {

    @Test func losingTheActiveInputFinishesSafely() {
        #expect(AudioRouteChange.decision(for: .inputDeviceLost, hasInput: true) == .finishSafely)
    }

    /// AirPods arriving mid-recording must not switch the microphone under the speaker, and must
    /// certainly not restart the file. Whatever iOS does with the route, the container keeps being
    /// written.
    @Test func aNewlyAvailableDeviceDoesNotEndTheRecording() {
        #expect(AudioRouteChange.decision(for: .inputDeviceAdded, hasInput: true) == .keepRecording)
    }

    @Test func anOrdinaryRouteConfigurationChangeDoesNotEndTheRecording() {
        #expect(AudioRouteChange.decision(for: .other, hasInput: true) == .keepRecording)
    }

    /// No input at all is the unambiguous case: there is nothing left to record with, whatever the
    /// notification said its reason was.
    @Test func noRemainingInputAlwaysFinishesSafely() {
        #expect(AudioRouteChange.decision(for: .other, hasInput: false) == .finishSafely)
        #expect(AudioRouteChange.decision(for: .inputDeviceAdded, hasInput: false) == .finishSafely)
    }

    /// Route semantics, never product names: "AirPods disconnected" reaches this type as an input
    /// that went away.
    @Test func theSystemReasonsMapOntoRouteSemantics() {
        #expect(AudioRouteChange.Reason(.oldDeviceUnavailable) == .inputDeviceLost)
        #expect(AudioRouteChange.Reason(.noSuitableRouteForCategory) == .inputDeviceLost)
        #expect(AudioRouteChange.Reason(.newDeviceAvailable) == .inputDeviceAdded)
        #expect(AudioRouteChange.Reason(.categoryChange) == .other)
        #expect(AudioRouteChange.Reason(.routeConfigurationChange) == .other)
        #expect(AudioRouteChange.Reason(.override) == .other)
        #expect(AudioRouteChange.Reason(.wakeFromSleep) == .other)
        #expect(AudioRouteChange.Reason(.unknown) == .other)
    }
}

// MARK: - Doubles for the capture model

/// A recorder that records what was asked of it. No microphone, no audio session, no route.
@MainActor
private final class RetentionRecorder: AudioRecording {
    var permission = true
    var startURL = URL(fileURLWithPath: "/tmp/rec-retention-test.m4a")
    var stopReturnsNil = false
    var level: Float = 0.3
    var onInterruption: (() -> Void)?

    private(set) var starts = 0
    private(set) var canceled = false
    private(set) var cleaned: [URL] = []
    private(set) var pauses = 0
    private(set) var resumes = 0

    func requestPermission() async -> Bool { permission }
    func start() throws -> URL { starts += 1; return startURL }
    func pause() { pauses += 1 }
    func resume() { resumes += 1 }
    func stop() -> URL? { stopReturnsNil ? nil : startURL }
    func cancel() { canceled = true; cleaned.append(startURL) }
    func cleanup(_ url: URL) { cleaned.append(url) }

    /// A call, Siri, or a route the recorder cannot continue on — all of which arrive the same way:
    /// the capture has stopped, and the audio recorded so far is on disk.
    func interrupt() { onInterruption?() }
}

/// A transcription service whose answer can change between attempts, which is the whole point of a
/// retry: the second attempt is the one most likely to succeed.
private final class ScriptedTranscriptionService: TranscriptionService, @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [Result<TranscriptionResult, TranscriptionError>]
    private var _calls: [URL] = []

    var sendsAudioOffDevice: Bool { false }

    /// The last answer repeats once the script runs out, so "fails forever" needs one entry.
    init(_ answers: [Result<TranscriptionResult, TranscriptionError>]) {
        self.answers = answers
    }

    convenience init(failing error: TranscriptionError) {
        self.init([.failure(error)])
    }

    static let text = "the words that were actually spoken"

    var calls: [URL] { lock.withLock { _calls } }
    var callCount: Int { lock.withLock { _calls.count } }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        let answer: Result<TranscriptionResult, TranscriptionError> = lock.withLock {
            _calls.append(audioURL)
            return answers.count > 1 ? answers.removeFirst() : (answers.first ?? .failure(.serviceUnavailable))
        }
        switch answer {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }

    static func success(_ text: String = ScriptedTranscriptionService.text)
        -> Result<TranscriptionResult, TranscriptionError> {
        .success(TranscriptionResult(text: text, detectedLanguages: ["en"]))
    }
}

/// Remembers what the allowance store was told, so a retry can be shown not to spend anything.
private final class SpyAllowance: VoiceAllowanceStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var _marked: [Date?] = []
    private var _clears = 0

    var unavailableUntil: Date? { nil }
    var marked: [Date?] { lock.withLock { _marked } }
    var clears: Int { lock.withLock { _clears } }

    func markUnavailable(until date: Date?) { lock.withLock { _marked.append(date) } }
    func clear() { lock.withLock { _clears += 1 } }
}

private struct GrantedConsent: TranscriptionConsentStoring {
    var hasConsented: Bool { true }
    func grant() {}
}

private struct NeverGrantedConsent: TranscriptionConsentStoring {
    var hasConsented: Bool { false }
    func grant() {}
}

/// Consent that starts unanswered and remembers the answer — the first-recording state.
private final class RecordingConsent: TranscriptionConsentStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var granted = false
    private var _asks = 0
    var hasConsented: Bool { lock.withLock { _asks += 1; return granted } }
    var asks: Int { lock.withLock { _asks } }
    func grant() { lock.withLock { granted = true } }
}

/// A clock the test moves by hand, so a 24-hour lifetime can be crossed without waiting a day.
private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var _now: Date
    init(_ now: Date = Date(timeIntervalSinceReferenceDate: 500_000)) { _now = now }
    var now: Date { lock.withLock { _now } }
    func advance(_ interval: TimeInterval) { lock.withLock { _now += interval } }
}

// MARK: - What survives a failure, and what does not

@MainActor
struct VoiceRetentionTests {

    private func make(_ recorder: RetentionRecorder,
                      _ service: TranscriptionService,
                      consent: TranscriptionConsentStoring = GrantedConsent(),
                      allowance: VoiceAllowanceStoring? = nil,
                      clock: TestClock = TestClock(),
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: service,
                          consent: consent,
                          allowance: allowance,
                          now: { clock.now },
                          onTranscript: onText)
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(60)) }

    /// The invariant the whole phase exists for.
    @Test func aRetryableFailureKeepsTheRecording() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .offline))
        await model.begin()
        model.done()
        await settle()

        #expect(model.phase == .failed(.offline))
        #expect(recorder.cleaned.isEmpty, "the recording was deleted by the failure it should survive")
        #expect(model.retainedRecording?.url == recorder.startURL)
    }

    @Test func successDeletesTheRecordingImmediately() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService([ScriptedTranscriptionService.success()]))
        await model.begin()
        model.done()
        await settle()

        #expect(recorder.cleaned == [recorder.startURL])
        #expect(model.retainedRecording == nil)
    }

    /// The relay heard the file and found no speech in it. Sending the same silence again cannot
    /// change that, so keeping it would only be As Told holding audio for no reason.
    @Test func noSpeechDeletesTheRecording() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .noSpeech))
        await model.begin()
        model.done()
        await settle()

        #expect(model.phase == .failed(.noSpeech))
        #expect(recorder.cleaned.contains(recorder.startURL))
        #expect(model.retainedRecording == nil)
    }

    @Test func theMonthlyCeilingRetainsNothing() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .monthlyLimitReached(resetsAt: nil)))
        await model.begin()
        model.done()
        await settle()

        #expect(recorder.cleaned.contains(recorder.startURL))
        #expect(model.retainedRecording == nil)
    }

    @Test func aRecordingOverTheLimitIsNotRetained() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .recordingTooLong(maxSeconds: 300)))
        await model.begin()
        model.done()
        await settle()

        #expect(recorder.cleaned.contains(recorder.startURL))
        #expect(model.retainedRecording == nil)
    }

    @Test func cancelDeletesTheRecording() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .offline))
        await model.begin()
        model.cancel()

        #expect(recorder.canceled)
        #expect(model.retainedRecording == nil)
    }

    /// Retry must never become a way around the one-time disclosure: declining deletes the audio, so
    /// there is nothing left to send.
    @Test func decliningTheDisclosureDeletesTheRecordingAndLeavesNothingToRetry() async {
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService([ScriptedTranscriptionService.success()])
        let model = make(recorder, service, consent: NeverGrantedConsent())
        await model.begin()
        model.done()
        #expect(model.phase == .needsConsent)

        model.discard()
        await settle()

        #expect(recorder.cleaned.contains(recorder.startURL))
        #expect(model.retainedRecording == nil)
        #expect(service.callCount == 0, "nothing may be uploaded before the disclosure is answered")

        model.retry()
        await settle()
        #expect(service.callCount == 0, "a declined recording must not be retryable")
    }

    // MARK: Delete Recording

    @Test func deleteRecordingRemovesTheAudioImmediately() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .offline))
        await model.begin()
        model.done()
        await settle()
        #expect(model.retainedRecording != nil)

        model.deleteRecording()

        #expect(recorder.cleaned.contains(recorder.startURL))
        #expect(model.retainedRecording == nil)
        #expect(model.phase == .idle)
    }

    @Test func deletingAfterAFailedRetryStillRemovesTheAudio() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .timedOut))
        await model.begin()
        model.done()
        await settle()
        model.retry()
        await settle()

        model.deleteRecording()
        #expect(recorder.cleaned.contains(recorder.startURL))
        #expect(model.retainedRecording == nil)
    }

    /// Leaving the note while a retained failure is on screen **keeps** the recording.
    ///
    /// Decided 2026-08-28, and it is the point of the phase: Back is navigation, not Delete
    /// Recording. The recording outlives the panel that failed and comes back on the recovery
    /// surface — see `VoiceRecoveryTests`, which owns the persistence half of this.
    @Test func leavingTheNoteDoesNotDeleteTheRetainedRecording() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .offline))
        await model.begin()
        model.done()
        await settle()
        #expect(model.retainedRecording != nil)

        model.finishOnLeave()          // EditorView.onDisappear

        #expect(!recorder.canceled, "Back deleted a recording the user could still retry")
        #expect(recorder.cleaned.isEmpty)
        #expect(model.retainedRecording != nil)
    }

    /// Leaving with nothing kept is still just leaving.
    @Test func leavingAfterAFailureThatKeptNothingIsHarmless() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .noSpeech))
        await model.begin()
        model.done()
        await settle()

        model.finishOnLeave()
        #expect(model.phase == .idle)
        #expect(model.retainedRecording == nil)
    }

    // MARK: Retry — one affordance, not one attempt

    @Test func retryUsesTheSameRecordingRatherThanMakingANewOne() async {
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService(failing: .offline)
        let model = make(recorder, service)
        await model.begin()
        model.done()
        await settle()

        model.retry()
        #expect(model.phase == .transcribing)
        await settle()

        #expect(service.calls == [recorder.startURL, recorder.startURL])
        #expect(recorder.starts == 1, "Retry re-recorded instead of re-sending")
    }

    /// The exact data loss `docs/10-voice-v2.md` §13 forbids: a second failure must not be the end
    /// of the recording. A flaky connection is the normal reason a retry is needed.
    @Test func aFailedRetryKeepsTheRecordingRetained() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .offline))
        await model.begin()
        model.done()
        await settle()

        model.retry()
        await settle()
        model.retry()
        await settle()

        #expect(model.phase == .failed(.offline))
        #expect(recorder.cleaned.isEmpty, "a failed Retry deleted the recording")
        #expect(model.retainedRecording?.url == recorder.startURL)
    }

    @Test func retryStaysAvailableUntilItSucceeds() async {
        var emitted: String?
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService([
            .failure(.offline),
            .failure(.timedOut),
            ScriptedTranscriptionService.success(),
        ])
        let model = make(recorder, service) { emitted = $0 }
        await model.begin()
        model.done()
        await settle()

        model.retry()
        await settle()
        model.retry()
        await settle()

        #expect(emitted == ScriptedTranscriptionService.text)
        #expect(model.phase == .idle)
        #expect(recorder.cleaned.contains(recorder.startURL), "a successful Retry must delete the audio")
        #expect(model.retainedRecording == nil)
    }

    /// Retry is a tap. Nothing drains a queue, nothing wakes up when the connection returns
    /// (`RULES.md` §2).
    @Test func nothingIsEverUploadedWithoutATap() async {
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService(failing: .offline)
        let model = make(recorder, service)
        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(200))

        #expect(service.callCount == 1, "the recording was re-uploaded without the user asking")
    }

    /// 24 hours later there is nothing to retry, and the audio goes rather than lingering.
    @Test func anExpiredRecordingIsDeletedRatherThanRetried() async {
        let clock = TestClock()
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService(failing: .offline)
        let model = make(recorder, service, clock: clock)
        await model.begin()
        model.done()
        await settle()

        clock.advance(TimeInterval(VoiceLimits.retryLifetimeSeconds))
        model.retry()
        await settle()

        #expect(service.callCount == 1, "expired audio was uploaded")
        #expect(recorder.cleaned.contains(recorder.startURL))
        #expect(model.retainedRecording == nil)
        #expect(model.phase == .idle)
    }

    /// The 24 hours run from the failure, not from the last tap. Restarting the clock on every
    /// Retry would let a recording live on the device indefinitely, one tap at a time — which is the
    /// quiet accumulation the lifetime exists to prevent.
    @Test func retryingDoesNotExtendTheLifetime() async {
        let clock = TestClock()
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService(failing: .offline)
        let model = make(recorder, service, clock: clock)
        await model.begin()
        model.done()
        await settle()
        let first = model.retainedRecording?.retainedAt

        clock.advance(60 * 60)
        model.retry()
        await settle()

        #expect(model.retainedRecording?.retainedAt == first)
        #expect(model.retainedRecording?.expiresAt == first?.addingTimeInterval(
            TimeInterval(VoiceLimits.retryLifetimeSeconds)))
    }

    @Test func aRecordingInsideTheLifetimeIsStillRetryable() async {
        let clock = TestClock()
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService(failing: .offline)
        let model = make(recorder, service, clock: clock)
        await model.begin()
        model.done()
        await settle()

        clock.advance(TimeInterval(VoiceLimits.retryLifetimeSeconds) - 60)
        model.retry()
        await settle()

        #expect(service.callCount == 2)
        #expect(model.retainedRecording != nil)
    }

    /// Consent is once per install, and a Retry is not a second install. The disclosure was answered
    /// before the first upload; the retry goes straight out (`docs/10-voice-v2.md` §16).
    @Test func retryNeverAsksForTheDisclosureAgain() async {
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService(failing: .offline)
        let consent = RecordingConsent()
        let model = make(recorder, service, consent: consent)

        await model.begin()
        model.done()
        #expect(model.phase == .needsConsent)
        model.grantConsent()
        await settle()
        #expect(model.retainedRecording != nil)

        model.retry()
        #expect(model.phase == .transcribing, "Retry re-opened the one-time disclosure")
        await settle()
        #expect(service.callCount == 2)
    }

    // MARK: The allowance is not spent by a failure

    /// The relay refunds every exit that returns no transcript, so a retry must not leave the app
    /// believing voice is spent either (`docs/04-voice-transcription.md` §14).
    @Test func aRetryableFailureDoesNotSpendTheMonthlyAllowance() async {
        let allowance = SpyAllowance()
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService([
            .failure(.offline),
            ScriptedTranscriptionService.success(),
        ])
        let model = make(recorder, service, allowance: allowance)
        await model.begin()
        model.done()
        await settle()

        #expect(allowance.marked.isEmpty, "a transient failure was recorded as the monthly ceiling")

        model.retry()
        await settle()

        #expect(allowance.marked.isEmpty)
        #expect(allowance.clears == 1, "the successful retry did not clear a stale refusal")
    }
}

// MARK: - Lifecycle: backgrounding, interruptions, route loss

@MainActor
struct VoiceLifecycleDurabilityTests {

    private func make(_ recorder: RetentionRecorder,
                      _ service: TranscriptionService,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: service,
                          consent: GrantedConsent(),
                          onTranscript: onText)
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(60)) }

    /// **Backgrounding MUST NEVER equal discard** (`docs/10-voice-v2.md` §14).
    @Test func backgroundingWhileRecordingFinishesWithTheAudio() async {
        var emitted: String?
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService([ScriptedTranscriptionService.success()])) {
            emitted = $0
        }
        await model.begin()
        model.finishOnBackground()
        await settle()

        #expect(emitted == ScriptedTranscriptionService.text)
        #expect(!recorder.canceled)
    }

    /// A paused capture holds audio that has already been spoken. Leaving for the home screen must
    /// not be the thing that throws it away.
    @Test func backgroundingWhilePausedFinishesWithTheAudio() async {
        var emitted: String?
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService([ScriptedTranscriptionService.success()])) {
            emitted = $0
        }
        await model.begin()
        model.pause()
        model.finishOnBackground()
        await settle()

        #expect(emitted == ScriptedTranscriptionService.text)
        #expect(!recorder.canceled)
        #expect(recorder.resumes == 0, "the recorder was resumed in the background")
    }

    @Test func backgroundingWhileTranscribingDoesNothingDestructive() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService([ScriptedTranscriptionService.success()]))
        await model.begin()
        model.done()
        #expect(model.phase == .transcribing)

        model.finishOnBackground()
        #expect(model.phase == .transcribing)
        await settle()
        #expect(model.phase == .idle)
        #expect(!recorder.canceled)
    }

    @Test func backgroundingAFailedCaptureLeavesTheRecordingRetained() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .offline))
        await model.begin()
        model.done()
        await settle()

        model.finishOnBackground()

        #expect(model.phase == .failed(.offline))
        #expect(model.retainedRecording != nil)
        #expect(recorder.cleaned.isEmpty)
    }

    /// A transcription interrupted by suspension that comes back as a transient failure lands in the
    /// same retained path as any other — one model, one failure path.
    @Test func aTranscriptionInterruptedByTheBackgroundRetainsItsAudio() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .timedOut))
        await model.begin()
        model.done()
        model.finishOnBackground()
        await settle()

        #expect(model.phase == .failed(.timedOut))
        #expect(model.retainedRecording?.url == recorder.startURL)
    }

    /// Siri, a call, or an input that disappeared: the capture stops, and what was spoken survives.
    @Test func anInterruptionWhilePausedFinishesRatherThanStrandingAResumeButton() async {
        var emitted: String?
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService([ScriptedTranscriptionService.success()])) {
            emitted = $0
        }
        await model.begin()
        model.pause()
        #expect(model.phase == .paused)

        recorder.interrupt()
        await settle()

        #expect(emitted == ScriptedTranscriptionService.text)
        #expect(model.phase == .idle, "a dead recorder was left behind a live Resume button")
    }

    /// A route the recorder cannot continue on arrives the same way an interruption does, and
    /// finishes the same way: the captured audio goes on to transcription.
    @Test func aLostInputFinishesTheCaptureWithWhatWasCaptured() async {
        let recorder = RetentionRecorder()
        let model = make(recorder, ScriptedTranscriptionService(failing: .offline))
        await model.begin()
        recorder.interrupt()
        await settle()

        #expect(!recorder.canceled, "losing the microphone deleted the recording")
        #expect(model.retainedRecording?.url == recorder.startURL)
    }
}

// MARK: - The launch sweep

@MainActor
struct RetainedAudioSweepTests {

    private func makeDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("retention-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeRecording(in dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("rec-\(UUID().uuidString).m4a")
        try Data("audio".utf8).write(to: url)
        return url
    }

    /// The 24 hours are a ceiling on how long audio may sit on disk, and the sweep is what enforces
    /// it (`RULES.md` §3: cleaned on launch "beyond the allowed retry lifetime").
    @Test func theSweepDeletesRetainedAudioOnceTheLifetimeHasRun() throws {
        let fm = FileManager.default
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = try makeRecording(in: dir)
        let now = Date(timeIntervalSinceReferenceDate: 900_000)
        let expired = RetainedVoiceRecording(
            url: url,
            retainedAt: now.addingTimeInterval(-TimeInterval(VoiceLimits.retryLifetimeSeconds) - 60)
        )

        AVAudioRecorderService.purgeAbandonedRecordings(in: dir, now: now, keeping: [expired])

        #expect(!fm.fileExists(atPath: url.path))
    }

    /// A recording still inside its lifetime, still owned by a capture that is offering it back, is
    /// the one thing the sweep may not touch.
    @Test func theSweepLeavesALiveRetainedRecordingAlone() throws {
        let fm = FileManager.default
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = try makeRecording(in: dir)
        let now = Date(timeIntervalSinceReferenceDate: 900_000)
        let live = RetainedVoiceRecording(url: url, retainedAt: now.addingTimeInterval(-3_600))

        AVAudioRecorderService.purgeAbandonedRecordings(in: dir, now: now, keeping: [live])

        #expect(fm.fileExists(atPath: url.path))
    }

    /// A recording nothing claims is abandoned, and goes. `keeping` is how the one recording the user
    /// can still retry is claimed — `VoiceRecoveryTests` covers the launch that does the claiming.
    @Test func anUnclaimedTemporaryRecordingIsSweptAway() throws {
        let fm = FileManager.default
        let dir = try makeDirectory()
        defer { try? fm.removeItem(at: dir) }
        let url = try makeRecording(in: dir)

        AVAudioRecorderService.purgeAbandonedRecordings(in: dir)

        #expect(!fm.fileExists(atPath: url.path))
    }
}

// MARK: - An existing note is never touched by a failed capture

@MainActor
struct VoiceRetryInNoteTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: Note.self, configurations: config))
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(60)) }

    /// The editor's own wiring: the transcript lands through `insertVoiceTranscript` at the offset
    /// captured *before* recording started, and nothing else in the flow writes to the note.
    private func makeCapture(_ editor: EditorModel,
                             at offset: Int,
                             recorder: RetentionRecorder,
                             service: TranscriptionService) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder, service: service, consent: GrantedConsent()) { text in
            editor.insertVoiceTranscript(text, atUTF16: offset)
        }
    }

    @Test func aFailedCaptureLeavesTheNoteExactlyAsItWas() async throws {
        let context = try makeContext()
        let note = Note(body: "what was already written")
        context.insert(note)
        let editor = EditorModel(note: note, context: context)
        let model = makeCapture(editor, at: 0,
                                recorder: RetentionRecorder(),
                                service: ScriptedTranscriptionService(failing: .offline))

        await model.begin()
        model.done()
        await settle()

        #expect(note.body == "what was already written")
        #expect(model.retainedRecording != nil)
    }

    @Test func aSuccessfulRetryInsertsTheTranscriptOnceAtTheCapturedCaret() async throws {
        let context = try makeContext()
        let note = Note(body: "before after")
        context.insert(note)
        let editor = EditorModel(note: note, context: context)
        let service = ScriptedTranscriptionService([
            .failure(.offline),
            ScriptedTranscriptionService.success("SPOKEN"),
        ])
        let model = makeCapture(editor, at: 7, recorder: RetentionRecorder(), service: service)

        await model.begin()
        model.done()
        await settle()
        model.retry()
        await settle()

        #expect(note.body.contains("SPOKEN"))
        // Once, and where the caret was — not appended, and not inserted twice by the failed attempt.
        #expect(note.body.components(separatedBy: "SPOKEN").count - 1 == 1)
        #expect(note.body.hasPrefix("before "))
    }

    /// Nothing about the note is ever sent, on the first attempt or on a retry — the relay receives
    /// audio and nothing else (`RULES.md` §2, §3).
    @Test func retrySendsTheAudioAndNothingElse() async throws {
        let context = try makeContext()
        let note = Note(body: "private words already in the note")
        context.insert(note)
        let editor = EditorModel(note: note, context: context)
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService(failing: .timedOut)
        let model = makeCapture(editor, at: 0, recorder: recorder, service: service)

        await model.begin()
        model.done()
        await settle()
        model.retry()
        await settle()

        #expect(service.calls == [recorder.startURL, recorder.startURL])
    }
}

// MARK: - No speech keeps its own affordance

@MainActor
struct VoiceNoSpeechTests {

    private func settle() async { try? await Task.sleep(for: .milliseconds(60)) }

    /// `Try Again` after no speech records again — there is no audio left to re-send, and re-sending
    /// silence would fail exactly the same way (`docs/10-voice-v2.md` §14).
    @Test func tryingAgainAfterNoSpeechRecordsRatherThanReUploading() async {
        let recorder = RetentionRecorder()
        let service = ScriptedTranscriptionService([
            .failure(.noSpeech),
            ScriptedTranscriptionService.success(),
        ])
        var emitted: String?
        let model = VoiceCaptureModel(recorder: recorder, service: service,
                                      consent: GrantedConsent()) { emitted = $0 }

        await model.begin()
        model.done()
        await settle()
        #expect(model.phase == .failed(.noSpeech))
        #expect(model.retainedRecording == nil)

        await model.begin()
        #expect(model.phase == .recording)
        #expect(recorder.starts == 2, "Try Again did not open the microphone again")

        model.done()
        await settle()
        #expect(emitted == ScriptedTranscriptionService.text)
    }
}
