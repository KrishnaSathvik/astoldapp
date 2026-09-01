import Testing
import Foundation
import SwiftData
@testable import Yourly

// MARK: Doubles

@MainActor
private final class FakeRecorder: AudioRecording {
    var permission: Bool
    var startURL = URL(fileURLWithPath: "/tmp/quick-voice-test.m4a")
    var stopReturnsNil = false
    private(set) var canceled = false
    private(set) var cleaned: [URL] = []
    var level: Float = 0.4
    var onCaptureEnded: ((RecordingStop) -> Void)?
    /// What the finalized container measures. `nil` stands in for a file with no usable duration —
    /// the one thing `.finishing` now refuses to send.
    var assetSeconds: Double? = 1
    var isCapturing = true

    init(permission: Bool = true) { self.permission = permission }

    func requestPermission() async -> Bool { permission }
    func start() throws -> URL { startURL }
    /// Pause/resume are not what these tests are about; they record the calls so a capture that
    /// pauses can still be driven through them.
    private(set) var pauses = 0
    private(set) var resumes = 0
    func pause() { pauses += 1 }
    func resume() { resumes += 1 }
    func finish() async -> FinishedRecording? {
        isCapturing = false
        return stopReturnsNil ? nil : FinishedRecording(url: startURL, assetSeconds: assetSeconds, bytes: 1)
    }
    func cancel() { canceled = true }
    func cleanup(_ url: URL) { cleaned.append(url) }
}

/// A service that *does* upload, so the one-time disclosure is actually reached. The bundled
/// `FakeTranscriptionService` keeps audio local and is therefore never gated.
private final class UploadingFakeService: TranscriptionService, @unchecked Sendable {
    var result: Result<TranscriptionResult, TranscriptionError>
    private(set) var callCount = 0

    var sendsAudioOffDevice: Bool { true }

    init(result: Result<TranscriptionResult, TranscriptionError> = .success(
        TranscriptionResult(text: "Uploaded transcript.", detectedLanguages: ["en"]))) {
        self.result = result
    }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        callCount += 1
        switch result {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

private struct NeverGrantedConsent: TranscriptionConsentStoring {
    var hasConsented: Bool { false }
    func grant() {}
}

// MARK: Tests

/// Voice V2 Phase 1 — Home Quick Voice.
///
/// The rule under test throughout: **a capture is transient until it earns a note**
/// (`docs/10-voice-v2.md` §3). Every path that is not a successful, non-empty transcript must leave
/// the store exactly as it found it.
@MainActor
struct QuickVoiceTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: Note.self, configurations: config))
    }

    private func noteCount(_ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<Note>())
    }

    /// Home's own wiring, reproduced exactly: the capture's success callback is the *only* thing that
    /// creates a note. Driving the real `VoiceCaptureModel` is what makes these tests meaningful —
    /// they prove the callback is unreachable on the failure paths, not merely that a guard exists.
    private func makeCapture(context: ModelContext,
                             recorder: FakeRecorder,
                             service: TranscriptionService,
                             consent: TranscriptionConsentStoring? = nil) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder, service: service, consent: consent) { transcript in
            guard let note = QuickVoiceNote.make(from: transcript) else { return }
            context.insert(note)
        }
    }

    private func settle() async {
        try? await Task.sleep(for: .milliseconds(60))
    }

    // MARK: Creation

    @Test func successfulCaptureCreatesExactlyOneNote() async throws {
        let context = try makeContext()
        let model = makeCapture(context: context,
                                recorder: FakeRecorder(),
                                service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        #expect(try noteCount(context) == 1)
    }

    @Test func createdNoteHoldsTheTranscriptVerbatimAndHasNoTitle() async throws {
        let context = try makeContext()
        let model = makeCapture(context: context,
                                recorder: FakeRecorder(),
                                service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        let note = try #require(try context.fetch(FetchDescriptor<Note>()).first)
        #expect(note.body == FakeTranscriptionService.sampleText)
        // No title is generated — inventing one is a second interpretation layer over the words
        // (docs/10-voice-v2.md §7).
        #expect(note.title == nil)
    }

    // MARK: Nothing is created on any other path

    @Test func cancelCreatesNoNote() async throws {
        let context = try makeContext()
        let recorder = FakeRecorder()
        let model = makeCapture(context: context,
                                recorder: recorder,
                                service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        model.cancel()
        await settle()

        #expect(try noteCount(context) == 0)
        #expect(recorder.canceled)
    }

    @Test func noSpeechCreatesNoNote() async throws {
        let context = try makeContext()
        let model = makeCapture(
            context: context,
            recorder: FakeRecorder(),
            service: FakeTranscriptionService(result: .failure(.noSpeech), delay: .milliseconds(1))
        )
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        #expect(model.phase == .failed(.noSpeech))
        #expect(try noteCount(context) == 0)
    }

    /// Also covers the empty-recording case, where the recorder itself hands back nothing.
    @Test func emptyRecordingCreatesNoNote() async throws {
        let context = try makeContext()
        let recorder = FakeRecorder()
        recorder.stopReturnsNil = true
        let model = makeCapture(context: context,
                                recorder: recorder,
                                service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        #expect(model.phase == .failed(.noSpeech))
        #expect(try noteCount(context) == 0)
    }

    @Test func transcriptionFailureCreatesNoNote() async throws {
        let context = try makeContext()
        let model = makeCapture(
            context: context,
            recorder: FakeRecorder(),
            service: FakeTranscriptionService(result: .failure(.offline), delay: .milliseconds(1))
        )
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        #expect(model.phase == .failed(.offline))
        #expect(try noteCount(context) == 0)
    }

    @Test func microphoneDenialCreatesNoNote() async throws {
        let context = try makeContext()
        let model = makeCapture(context: context,
                                recorder: FakeRecorder(permission: false),
                                service: FakeTranscriptionService(delay: .milliseconds(1)))
        await model.begin()
        await settle()

        #expect(model.phase == .permissionDenied)
        #expect(try noteCount(context) == 0)
    }

    @Test func decliningTheDisclosureUploadsNothingAndCreatesNoNote() async throws {
        let context = try makeContext()
        let recorder = FakeRecorder()
        let service = UploadingFakeService()
        let model = makeCapture(context: context,
                                recorder: recorder,
                                service: service,
                                consent: NeverGrantedConsent())
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        // Stopped at the disclosure with the audio still on disk, unsent.
        #expect(model.phase == .needsConsent)
        #expect(service.callCount == 0)

        model.discard()          // "Cancel" on the disclosure
        await settle()

        #expect(service.callCount == 0)
        #expect(try noteCount(context) == 0)
        #expect(recorder.cleaned.contains(recorder.startURL))   // declined audio is deleted
    }

    @Test func acceptingTheDisclosureSendsTheWaitingRecordingAndCreatesTheNote() async throws {
        let context = try makeContext()
        let service = UploadingFakeService()
        let model = makeCapture(context: context,
                                recorder: FakeRecorder(),
                                service: service,
                                consent: NeverGrantedConsent())
        await model.begin()
        model.done()
        await settled(model)
        await settle()
        #expect(model.phase == .needsConsent)

        model.grantConsent()
        await settle()

        #expect(service.callCount == 1)
        #expect(try noteCount(context) == 1)
    }

    // MARK: The note-building rule itself

    @Test func makeReturnsNilForATranscriptWithNoVisibleText() {
        #expect(QuickVoiceNote.make(from: "") == nil)
        #expect(QuickVoiceNote.make(from: "   \n  ") == nil)
    }

    @Test func makeKeepsTheTranscriptExactly() throws {
        let spoken = "Tomorrow morning temple ki vellali and then Costco ki vellali."
        let note = try #require(QuickVoiceNote.make(from: spoken))
        #expect(note.body == spoken)
        #expect(note.title == nil)
    }

    // MARK: The keyboard rule

    /// Voice must never summon a keyboard that was not already visible (`docs/10-voice-v2.md` §7).
    ///
    /// `EditorView` gives the body first responder to an **empty draft** and to nothing else, so the
    /// rule holds for Quick Voice precisely because the note it opens already has a body. This pins
    /// the property the keyboard behavior actually depends on; that a non-focused editor draws no
    /// keyboard is `EditorView`'s existing, separately covered behavior.
    @Test func aQuickVoiceNoteIsNotAnEmptyDraftSoTheEditorDoesNotFocusIt() throws {
        let note = try #require(QuickVoiceNote.make(from: FakeTranscriptionService.sampleText))
        #expect(note.isEmptyDraft == false)
    }

    /// The other half of the same rule, and the reason it is worth a test: `+` must keep raising the
    /// keyboard. The two creation paths now deliberately differ, and nothing else asserts that.
    @Test func aTypedNewNoteIsAnEmptyDraftSoTheEditorStillFocusesIt() {
        #expect(Note().isEmptyDraft)
    }
}

/// Let a capture leave `.finishing`.
///
/// Closing the recorder and measuring the container it wrote is asynchronous
/// (`AudioRecording.finish()`), so **Done** now puts a capture into `.finishing` for a moment
/// rather than straight into what comes after it. That wait is the point — it is where the
/// invariant lives that nothing is uploaded before the file is finalized and measured — so these
/// tests wait for it rather than assuming it away.
///
/// Yields rather than sleeping. A sleep here would also step over `.transcribing`, which several of
/// these tests are specifically about being in.
@MainActor
private func settled(_ model: VoiceCaptureModel) async {
    for _ in 0..<200 {
        if model.phase != .finishing { return }
        await Task.yield()
    }
}
