import Testing
import Foundation
import AVFoundation
@testable import Yourly

/// The capture's account of itself must match the recorder's.
///
/// Every test here is a regression test for one of two defects found by audit on 2026-08-30, both of
/// which produced the same user-visible outcome — a note holding the first few seconds of a much
/// longer thought, reported as a success:
///
///  1. `AVAudioRecorder` had no delegate, so a recorder that stopped on its own was invisible. The
///     capture went on saying `recording`, the timer went on counting, and **Done** then finalized
///     whatever had been written before the failure and uploaded it like an ordinary recording.
///  2. `.finishing` set a phase and moved straight on, so the upload could begin while the encoder
///     was still writing the container.
@MainActor
private final class LifecycleRecorder: AudioRecording {
    var startURL = URL(fileURLWithPath: "/tmp/rec-lifecycle.m4a")
    /// What the finalized container measures. `nil` is a file with no usable duration.
    var assetSeconds: Double? = 12
    var isCapturing = true
    var level: Float = 0.4
    var onCaptureEnded: ((RecordingStop) -> Void)?

    private(set) var finishes = 0
    private(set) var canceled = false
    private(set) var cleaned: [URL] = []

    /// Held so a test can decide *when* finalization completes, which is the only way to observe
    /// that nothing is uploaded while it is still in flight.
    var finishGate: (() async -> Void)?

    func requestPermission() async -> Bool { true }
    func start() throws -> URL { isCapturing = true; return startURL }
    func pause() {}
    func resume() {}

    func finish() async -> FinishedRecording? {
        finishes += 1
        await finishGate?()
        isCapturing = false
        return FinishedRecording(url: startURL, assetSeconds: assetSeconds, bytes: 4096)
    }

    func cancel() { canceled = true; isCapturing = false }
    func cleanup(_ url: URL) { cleaned.append(url) }

    /// The recorder dying on its own: an encoder failure, or a finish nobody asked for.
    func failUnexpectedly() { isCapturing = false; onCaptureEnded?(.unexpected) }
    /// A call or Siri taking the microphone — a different fact, and still never a discard.
    func interrupt() { onCaptureEnded?(.interrupted) }
}

/// Counts uploads so a test can prove one did *not* happen.
private actor CountingService: TranscriptionService {
    private(set) var calls = 0
    private let text: String

    init(text: String = "captured words") { self.text = text }

    nonisolated var sendsAudioOffDevice: Bool { false }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        calls += 1
        return TranscriptionResult(text: text, detectedLanguages: [], allowanceExhaustedUntil: nil)
    }

    func callCount() -> Int { calls }
}

@MainActor
struct VoiceRecorderLifecycleTests {

    private func make(recorder: LifecycleRecorder,
                      service: TranscriptionService,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: service,
                          retention: NoRetainedRecordingStore(),
                          onTranscript: onText)
    }

    // MARK: - Fix 1: the recorder can no longer stop unnoticed

    /// The delegate is the whole mechanism. Without conformance there is no callback, and without a
    /// callback every other test in this file is asserting against a fiction.
    @Test func theRecorderServiceIsItsOwnDelegate() {
        #expect((AVAudioRecorderService() as Any) is AVAudioRecorderDelegate)
    }

    /// The defect, stated as a test: a capture may not still call itself `recording` once the
    /// recorder underneath it has stopped.
    @Test func anUnexpectedStopCannotLeaveTheCaptureRecording() async {
        let recorder = LifecycleRecorder()
        let model = make(recorder: recorder, service: CountingService())
        await model.begin()
        #expect(model.phase == .recording)

        recorder.failUnexpectedly()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase != .recording)
        #expect(model.phase == .stoppedUnexpectedly)
    }

    /// An encoder failure must not arrive looking like Done. Nothing is uploaded, no transcript is
    /// emitted, and the capture does not slide to `idle` behind a note that has already been made.
    @Test func anUnexpectedStopIsNeverAnOrdinarySuccess() async {
        var emitted: String?
        let recorder = LifecycleRecorder()
        let service = CountingService()
        let model = make(recorder: recorder, service: service) { emitted = $0 }
        await model.begin()

        recorder.failUnexpectedly()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(emitted == nil)
        #expect(await service.callCount() == 0)
        #expect(model.phase == .stoppedUnexpectedly)
    }

    /// And it must not throw the words away either. What was captured is kept and retained, so it
    /// survives Back and the process ending exactly as a failed upload's recording does
    /// (`RULES.md` §2).
    @Test func anUnexpectedStopKeepsWhatWasCaptured() async {
        let recorder = LifecycleRecorder()
        let model = make(recorder: recorder, service: CountingService())
        await model.begin()

        recorder.failUnexpectedly()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.retainedRecording != nil)
        #expect(recorder.cleaned.isEmpty)
    }

    /// A first recording that stopped unexpectedly must not be persisted for a later surface to
    /// offer back: the recovery path treats a retained recording as one whose disclosure was already
    /// accepted, because until this state existed one could only be created after a *sent* upload.
    /// The audio is still held for the decision on screen — it is only the memory of it that waits.
    @Test func anUnexpectedStopBeforeTheDisclosureIsNotRememberedAcrossTheProcess() async {
        let recorder = LifecycleRecorder()
        let store = RecordingMemory()
        let model = VoiceCaptureModel(recorder: recorder,
                                      service: CountingService(),
                                      consent: NeverGranted(),
                                      retention: store,
                                      onTranscript: { _ in })
        await model.begin()

        recorder.failUnexpectedly()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .stoppedUnexpectedly)
        #expect(store.remembered == nil, "an undisclosed recording is not persisted")
        #expect(recorder.cleaned.isEmpty, "and it is still there to decide about")
    }

    /// The user's decision, and only the user's: from the unexpected-stop state, **Transcribe**
    /// sends what survived.
    @Test func theUserCanSendWhatSurvivedAnUnexpectedStop() async {
        var emitted: String?
        let recorder = LifecycleRecorder()
        let model = make(recorder: recorder, service: CountingService()) { emitted = $0 }
        await model.begin()
        recorder.failUnexpectedly()
        try? await Task.sleep(for: .milliseconds(50))

        model.transcribeCaptured()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(emitted == "captured words")
    }

    /// The timer is arithmetic over a monotonic clock and knows nothing about the microphone, so it
    /// went on climbing over a recorder that had already died. It stops when the capture actually
    /// stops, whichever way it stopped.
    @Test func theRecordedClockStopsWhenTheRecorderDoes() async {
        let recorder = LifecycleRecorder()
        let model = make(recorder: recorder, service: CountingService())
        await model.begin()

        recorder.failUnexpectedly()
        try? await Task.sleep(for: .milliseconds(30))
        let atStop = model.elapsedRecording
        try? await Task.sleep(for: .milliseconds(60))

        #expect(model.elapsedRecording == atStop)
    }

    /// An interruption is still an interruption. A call or Siri finishes the capture and transcribes
    /// what was said — the locked behavior (`RULES.md` §2) — and the new ending must not have
    /// quietly captured it.
    @Test func anInterruptionStillFinishesAndTranscribes() async {
        var emitted: String?
        let recorder = LifecycleRecorder()
        let model = make(recorder: recorder, service: CountingService()) { emitted = $0 }
        await model.begin()

        recorder.interrupt()
        try? await Task.sleep(for: .milliseconds(80))

        #expect(emitted == "captured words")
        #expect(model.phase == .idle)
    }

    // MARK: - Fix 3: `.finishing` is a step, not a label

    /// Nothing may be sent while the recorder is still closing its file. The gate holds finalization
    /// open; the capture must sit in `.finishing` with no upload made.
    @Test func nothingIsUploadedWhileTheFileIsStillBeingFinalized() async {
        let recorder = LifecycleRecorder()
        let service = CountingService()
        let model = make(recorder: recorder, service: service)
        let gate = AsyncGate()
        recorder.finishGate = { await gate.wait() }

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .finishing)
        #expect(await service.callCount() == 0)

        await gate.open()
        try? await Task.sleep(for: .milliseconds(80))

        #expect(await service.callCount() == 1)
    }

    /// A container with no usable duration is not a recording. The relay measures the same way and
    /// refuses what it cannot measure, so this is refused here rather than a round trip later.
    @Test func anUnmeasurableContainerIsNeverUploaded() async {
        let recorder = LifecycleRecorder()
        recorder.assetSeconds = nil
        let service = CountingService()
        let model = make(recorder: recorder, service: service)

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(80))

        #expect(await service.callCount() == 0)
        #expect(model.phase == .failed(.noSpeech))
    }

    /// The finalized file is measured on every ending, so the drift between what the microphone was
    /// open for and what the container holds is always available to be noticed.
    @Test func everyEndingGoesThroughFinalization() async {
        let recorder = LifecycleRecorder()
        let model = make(recorder: recorder, service: CountingService())
        await model.begin()

        recorder.failUnexpectedly()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(recorder.finishes == 1)
    }
}

/// A latch a test can hold closed, so "while this is still in flight" is a state the test controls
/// rather than a race it hopes to win.
private actor AsyncGate {
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for continuation in pending { continuation.resume() }
    }
}

/// Consent that has never been granted — the first-recording state.
private struct NeverGranted: TranscriptionConsentStoring {
    var hasConsented: Bool { false }
    func grant() {}
}

/// Remembers one recording, so a test can see whether anything was persisted.
///
/// A value type with a class box behind it: `RetainedRecordingStoring` is `Sendable` and its methods
/// are not isolated, so the store cannot be an actor-bound class — but a test still has to read back
/// what was written to it.
private struct RecordingMemory: RetainedRecordingStoring {
    private final class Box: @unchecked Sendable { var value: RetainedVoiceRecording? }
    private let box = Box()

    var remembered: RetainedVoiceRecording? { box.value }
    func remember(_ recording: RetainedVoiceRecording) { box.value = recording }
    func forget() { box.value = nil }
}
