import Testing
import Foundation
import SwiftData
@testable import Yourly

/// One-shot recovery of a retained recording (`docs/10-voice-v2.md` §13, decided 2026-08-28).
///
/// The promise Phase 2B exists to keep is that once useful audio has been recorded, As Told protects
/// it **until it becomes text, the user deletes it, or the 24 hours run out**. Leaving the note and
/// the process ending are neither of those three things, so neither may delete the recording — which
/// is what these tests hold down.
///
/// What it must *not* become is equally load-bearing: at most one retained recording, offered back on
/// one surface with two controls. No list, no playback, no history, no export (`RULES.md` §7).

// MARK: - Doubles

@MainActor
private final class RecoveryRecorder: AudioRecording {
    var startURL = URL(fileURLWithPath: "/tmp/rec-recovery-test.m4a")
    var level: Float = 0.2
    var onCaptureEnded: ((RecordingStop) -> Void)?
    /// What the finalized container measures. `nil` stands in for a file with no usable duration —
    /// the one thing `.finishing` now refuses to send.
    var assetSeconds: Double? = 1
    var isCapturing = true
    private(set) var canceled = false
    private(set) var cleaned: [URL] = []

    func requestPermission() async -> Bool { true }
    func start() throws -> URL { startURL }
    func pause() {}
    func resume() {}
    func finish() async -> FinishedRecording? {
        isCapturing = false
        return FinishedRecording(url: startURL, assetSeconds: assetSeconds, bytes: 1)
    }
    func cancel() { canceled = true; cleaned.append(startURL) }
    func cleanup(_ url: URL) { cleaned.append(url) }
}

private final class RecoveryService: TranscriptionService, @unchecked Sendable {
    private let lock = NSLock()
    private var answers: [Result<TranscriptionResult, TranscriptionError>]
    private var _calls: [URL] = []

    var sendsAudioOffDevice: Bool { false }
    static let text = "the recovered words"

    init(_ answers: [Result<TranscriptionResult, TranscriptionError>]) { self.answers = answers }
    convenience init(failing error: TranscriptionError) { self.init([.failure(error)]) }
    static var succeeding: RecoveryService {
        RecoveryService([.success(TranscriptionResult(text: text, detectedLanguages: ["en"]))])
    }

    var calls: [URL] { lock.withLock { _calls } }

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
}

private struct AlwaysConsented: TranscriptionConsentStoring {
    var hasConsented: Bool { true }
    func grant() {}
}

/// A defaults suite of its own per test, so nothing leaks between them or into the app's.
private func makeStore() -> (UserDefaultsRetainedRecording, UserDefaults, String) {
    let name = "retained-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    return (UserDefaultsRetainedRecording(defaults: defaults), defaults, name)
}

@MainActor
private func makeAudioFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(AVAudioRecorderService.tempPrefix)\(UUID().uuidString)")
        .appendingPathExtension("m4a")
    try Data("audio".utf8).write(to: url)
    return url
}

// MARK: - What is remembered

@MainActor
struct RetainedRecordingStoreTests {

    @Test func aRetainedRecordingSurvivesRelaunch() throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date(timeIntervalSinceReferenceDate: 700_000)

        store.remember(RetainedVoiceRecording(url: url, retainedAt: now, origin: .quickVoice))

        // A fresh instance over the same defaults stands in for the next launch.
        let next = UserDefaultsRetainedRecording(defaults: defaults)
        let recovered = try #require(next.recoverable(at: now.addingTimeInterval(60)))
        #expect(recovered.url == url)
        #expect(recovered.retainedAt == now)
        #expect(recovered.origin == .quickVoice)
    }

    /// The temporary directory's path contains the app's own identifier and changes between installs
    /// and updates, so a stored absolute path goes stale. The **name** is what is remembered, and it
    /// is resolved against wherever temporary audio lives now.
    @Test func theRecordingIsFoundByNameRatherThanByAStalePath() throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let stalePath = URL(fileURLWithPath: "/var/mobile/Containers/Data/Application/GONE/tmp")
            .appendingPathComponent(url.lastPathComponent)
        let now = Date(timeIntervalSinceReferenceDate: 700_000)

        store.remember(RetainedVoiceRecording(url: stalePath, retainedAt: now, origin: .note))

        let recovered = try #require(store.recoverable(at: now))
        #expect(recovered.url == url, "the recording was looked for where it used to live")
    }

    /// 24 hours is a ceiling, and the launch that finds an expired recording is where it is enforced.
    @Test func anExpiredRecordingIsNotRecoverableAndIsForgotten() throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let retainedAt = Date(timeIntervalSinceReferenceDate: 700_000)
        store.remember(RetainedVoiceRecording(url: url, retainedAt: retainedAt, origin: .quickVoice))

        let after = retainedAt.addingTimeInterval(TimeInterval(VoiceLimits.retryLifetimeSeconds))
        #expect(store.recoverable(at: after) == nil)
        #expect(store.remembered == nil, "the expired recording is still remembered")
    }

    /// A file that is gone — swept, wiped by the system, deleted by another path — is not a recording
    /// to offer back, and the memory of it goes with it.
    @Test func aMissingFileIsNotRecoverableAndIsForgotten() throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        let now = Date(timeIntervalSinceReferenceDate: 700_000)
        store.remember(RetainedVoiceRecording(url: url, retainedAt: now, origin: .quickVoice))
        try FileManager.default.removeItem(at: url)

        #expect(store.recoverable(at: now) == nil)
        #expect(store.remembered == nil)
    }

    @Test func forgettingLeavesNothingToRecover() throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let now = Date(timeIntervalSinceReferenceDate: 700_000)

        store.remember(RetainedVoiceRecording(url: url, retainedAt: now, origin: .note))
        store.forget()

        #expect(store.recoverable(at: now) == nil)
    }

    /// One retained recording, ever. A second retryable failure replaces the first rather than
    /// starting a collection (`RULES.md` §7 — no audio archive).
    @Test func rememberingASecondRecordingReplacesTheFirst() throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let first = try makeAudioFile(), second = try makeAudioFile()
        defer { for u in [first, second] { try? FileManager.default.removeItem(at: u) } }
        let now = Date(timeIntervalSinceReferenceDate: 700_000)

        store.remember(RetainedVoiceRecording(url: first, retainedAt: now, origin: .quickVoice))
        store.remember(RetainedVoiceRecording(url: second, retainedAt: now, origin: .quickVoice))

        #expect(store.recoverable(at: now)?.url == second)
    }
}

// MARK: - The capture remembers and forgets

@MainActor
struct RetentionPersistenceTests {

    private func settle() async { try? await Task.sleep(for: .milliseconds(60)) }

    private func make(_ recorder: RecoveryRecorder,
                      _ service: TranscriptionService,
                      _ store: RetainedRecordingStoring,
                      origin: RetainedVoiceRecording.Origin = .quickVoice,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: service,
                          consent: AlwaysConsented(),
                          retention: store,
                          origin: origin,
                          onTranscript: onText)
    }

    @Test func aRetryableFailureIsRememberedForTheNextLaunch() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: recorder.startURL) }

        let model = make(recorder, RecoveryService(failing: .offline), store)
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        let remembered = try #require(store.remembered)
        #expect(remembered.url == recorder.startURL)
        #expect(remembered.retainedAt == model.retainedRecording?.retainedAt)
    }

    @Test func aFailureThatKeepsNothingRemembersNothing() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        let model = make(recorder, RecoveryService(failing: .noSpeech), store)
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        #expect(store.remembered == nil)
    }

    @Test func successForgetsTheRecording() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        let model = make(recorder, RecoveryService([
            .failure(.offline),
            .success(TranscriptionResult(text: RecoveryService.text, detectedLanguages: [])),
        ]), store)
        await model.begin()
        model.done()
        await settled(model)
        await settle()
        #expect(store.remembered != nil)

        model.retry()
        await settle()

        #expect(store.remembered == nil, "a transcribed recording was still remembered")
    }

    @Test func deleteRecordingForgetsIt() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = make(RecoveryRecorder(), RecoveryService(failing: .offline), store)
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        model.deleteRecording()
        #expect(store.remembered == nil)
    }

    /// **Back is navigation, not Delete Recording** (decided 2026-08-28). Leaving the note closes the
    /// panel; the recording it was offering back stays on disk and comes back through recovery.
    @Test func leavingTheNoteKeepsTheRetainedRecording() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: recorder.startURL) }
        let model = make(recorder, RecoveryService(failing: .offline), store, origin: .note)
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        model.finishOnLeave()          // EditorView.onDisappear

        #expect(!recorder.canceled, "Back deleted the recording")
        #expect(recorder.cleaned.isEmpty)
        #expect(store.remembered?.url == recorder.startURL)
        #expect(FileManager.default.fileExists(atPath: recorder.startURL.path))
    }

    /// The origin is remembered because the *copy* depends on it: a recording captured inside a note
    /// has to say, before the retry, that its transcript will arrive as a new note.
    @Test func theOriginIsRemembered() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = make(RecoveryRecorder(), RecoveryService(failing: .offline), store, origin: .note)
        await model.begin()
        model.done()
        await settled(model)
        await settle()

        #expect(store.remembered?.origin == .note)
    }
}

// MARK: - Recovering it on the next launch

@MainActor
struct RecoveredRecordingTests {

    private func settle() async { try? await Task.sleep(for: .milliseconds(60)) }

    private func make(_ recording: RetainedVoiceRecording,
                      _ service: TranscriptionService,
                      _ store: RetainedRecordingStoring,
                      now: Date = .now,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recovering: recording, service: service, now: { now }, retention: store,
                          onTranscript: onText)
    }

    @Test func retryingARecoveredRecordingTranscribesTheSameFile() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        let recording = RetainedVoiceRecording(url: url, retainedAt: .now, origin: .quickVoice)
        store.remember(recording)
        let service = RecoveryService.succeeding
        var emitted: String?
        let model = make(recording, service, store) { emitted = $0 }

        model.retry()
        #expect(model.phase == .transcribing)
        await settle()

        #expect(service.calls == [url])
        #expect(emitted == RecoveryService.text)
        #expect(model.phase == .idle)
        #expect(!FileManager.default.fileExists(atPath: url.path), "the recovered audio outlived its transcript")
        #expect(store.remembered == nil)
    }

    /// A recovered recording is still one affordance, not one attempt.
    @Test func aFailedRecoveryRetryKeepsTheRecordingAndItsOriginalClock() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let retainedAt = Date(timeIntervalSinceReferenceDate: 800_000)
        let recording = RetainedVoiceRecording(url: url, retainedAt: retainedAt, origin: .quickVoice)
        store.remember(recording)
        // The clock is pinned an hour after the failure: the recording is well inside its lifetime,
        // which is what makes this a test about retrying rather than about expiry.
        let model = make(recording, RecoveryService(failing: .offline), store,
                         now: retainedAt.addingTimeInterval(3_600))

        model.retry()
        await settle()

        #expect(model.phase == .failed(.offline))
        #expect(model.retainedRecording?.retainedAt == retainedAt, "recovery restarted the 24 hours")
        #expect(store.remembered?.retainedAt == retainedAt)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func deletingARecoveredRecordingRemovesTheFile() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        let recording = RetainedVoiceRecording(url: url, retainedAt: .now, origin: .note)
        store.remember(recording)
        let model = make(recording, RecoveryService.succeeding, store)

        model.deleteRecording()

        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(store.remembered == nil)
        #expect(model.retainedRecording == nil)
    }

    /// The whole point of recovering it: the words become a note.
    @Test func aRecoveredQuickVoiceRetryCreatesOneOrdinaryNote() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let url = try makeAudioFile()
        let context = ModelContext(try ModelContainer(
            for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let recording = RetainedVoiceRecording(url: url, retainedAt: .now, origin: .quickVoice)
        store.remember(recording)

        // Home's own wiring, reproduced: the transcript callback is the only thing that makes a note.
        let model = make(recording, RecoveryService.succeeding, store) { transcript in
            guard let note = QuickVoiceNote.make(from: transcript) else { return }
            context.insert(note)
        }
        model.retry()
        await settle()

        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.count == 1)
        #expect(notes.first?.body == RecoveryService.text)
        #expect(notes.first?.title == nil, "a recovered recording invented a title")
    }

    /// A recording captured inside a note comes back as a **new** note, because the caret it was
    /// aimed at belonged to an editing session that no longer exists. Guessing an offset into a note
    /// that may have been edited since is how a transcript lands in the middle of a sentence.
    @Test func aRecoveredInNoteRecordingIsSaidToBecomeANewNote() {
        #expect(VoiceErrorCopy.recoveryNotice(for: .note) == "This recording will be saved as a new note.")
        #expect(VoiceErrorCopy.recoveryNotice(for: .quickVoice) == nil,
                "Quick Voice always makes a new note; saying so would be noise")
    }

    @Test func theRecoverySurfaceSaysWhatHappened() {
        #expect(VoiceErrorCopy.recoveryTitle == "We saved a recording that couldn't be transcribed.")
    }
}

// MARK: - The launch sweep, as the app actually calls it

@MainActor
struct LaunchSweepRecoveryTests {

    /// The sweep and the store, wired the way `AppRootView` wires them.
    @Test func launchKeepsAValidRetainedRecordingAndSweepsEverythingElse() throws {
        let fm = FileManager.default
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let dir = fm.temporaryDirectory.appendingPathComponent("launch-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let kept = dir.appendingPathComponent("rec-kept.m4a")
        let abandoned = dir.appendingPathComponent("rec-abandoned.m4a")
        for url in [kept, abandoned] { try Data("audio".utf8).write(to: url) }
        let now = Date(timeIntervalSinceReferenceDate: 900_000)
        store.remember(RetainedVoiceRecording(url: kept, retainedAt: now.addingTimeInterval(-3_600),
                                              origin: .quickVoice))

        let recoverable = store.recoverable(at: now, in: dir)
        AVAudioRecorderService.purgeAbandonedRecordings(
            in: dir, now: now, keeping: recoverable.map { [$0] } ?? [])

        #expect(fm.fileExists(atPath: kept.path), "the recording the user can still retry was swept")
        #expect(!fm.fileExists(atPath: abandoned.path))
    }

    @Test func launchSweepsARecordingPastItsLifetime() throws {
        let fm = FileManager.default
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let dir = fm.temporaryDirectory.appendingPathComponent("launch-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let expired = dir.appendingPathComponent("rec-expired.m4a")
        try Data("audio".utf8).write(to: expired)
        let now = Date(timeIntervalSinceReferenceDate: 900_000)
        store.remember(RetainedVoiceRecording(
            url: expired,
            retainedAt: now.addingTimeInterval(-TimeInterval(VoiceLimits.retryLifetimeSeconds) - 1),
            origin: .quickVoice))

        let recoverable = store.recoverable(at: now, in: dir)
        AVAudioRecorderService.purgeAbandonedRecordings(
            in: dir, now: now, keeping: recoverable.map { [$0] } ?? [])

        #expect(recoverable == nil)
        #expect(!fm.fileExists(atPath: expired.path))
        #expect(store.remembered == nil)
    }
}

// MARK: - Leaving while the recording is still being sent

/// A service that takes its time, so a test can leave the editor *during* the upload.
private final class SlowService: TranscriptionService, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls = 0
    let delay: Duration
    let answer: Result<TranscriptionResult, TranscriptionError>

    var sendsAudioOffDevice: Bool { false }
    var calls: Int { lock.withLock { _calls } }

    init(delay: Duration = .milliseconds(80),
         answer: Result<TranscriptionResult, TranscriptionError> = .success(
            TranscriptionResult(text: "late words", detectedLanguages: []))) {
        self.delay = delay
        self.answer = answer
    }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        lock.withLock { _calls += 1 }
        // Deliberately does **not** honour cancellation: a real upload that has already reached the
        // relay comes back whether or not anybody is still listening, and that late answer is exactly
        // what must not be allowed to touch anything.
        try? await Task.sleep(for: delay)
        switch answer {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}

/// **Back is navigation, not discard** — including after Done, while the upload is in flight
/// (decided 2026-08-28). The user has finished speaking and committed the recording; ordinary
/// navigation may not be what destroys it.
@MainActor
struct LeavingMidTranscriptionTests {

    private func settle() async { try? await Task.sleep(for: .milliseconds(250)) }

    private func make(_ recorder: RecoveryRecorder,
                      _ service: TranscriptionService,
                      _ store: RetainedRecordingStoring,
                      origin: RetainedVoiceRecording.Origin = .note,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: service,
                          consent: AlwaysConsented(),
                          retention: store,
                          origin: origin,
                          onTranscript: onText)
    }

    @Test func leavingWhileTranscribingKeepsTheRecording() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: recorder.startURL) }
        let model = make(recorder, SlowService(), store)

        await model.begin()
        model.done()
        await settled(model)
        #expect(model.phase == .transcribing)

        model.finishOnLeave()          // EditorView.onDisappear, mid-upload

        #expect(model.retainedRecording?.url == recorder.startURL,
                "the recording was not claimed before the upload was abandoned")
        #expect(store.remembered?.url == recorder.startURL)
        #expect(!recorder.canceled, "leaving deleted a recording the user had already spoken")
        #expect(recorder.cleaned.isEmpty)
        #expect(FileManager.default.fileExists(atPath: recorder.startURL.path))
    }

    /// The race the whole generation check exists for: the abandoned attempt answering *successfully*
    /// after the editor is gone. It must not insert into the note that no longer exists, must not make
    /// a second note, and must not delete the recording out from under recovery.
    @Test func aLateSuccessFromTheAbandonedAttemptChangesNothing() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: recorder.startURL) }
        var emissions = 0
        let model = make(recorder, SlowService(), store) { _ in emissions += 1 }

        await model.begin()
        model.done()
        await settled(model)
        model.finishOnLeave()
        await settle()                 // the abandoned upload finishes here

        #expect(emissions == 0, "a transcript landed in a note nobody was looking at")
        #expect(model.retainedRecording != nil)
        #expect(store.remembered != nil, "the late answer cleared the recovery record")
        #expect(FileManager.default.fileExists(atPath: recorder.startURL.path))
    }

    /// The dangerous half: a late **non-retryable** failure would ordinarily delete its audio. From an
    /// abandoned attempt it must do nothing at all.
    @Test func aLateFailureFromTheAbandonedAttemptDoesNotDeleteTheRecording() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: recorder.startURL) }
        let model = make(recorder, SlowService(answer: .failure(.noSpeech)), store)

        await model.begin()
        model.done()
        await settled(model)
        model.finishOnLeave()
        await settle()

        #expect(model.retainedRecording != nil, "a late no-speech deleted the retained recording")
        #expect(store.remembered != nil)
        #expect(recorder.cleaned.isEmpty)
        #expect(FileManager.default.fileExists(atPath: recorder.startURL.path))
    }

    /// What the user sees next: the same recovery offer, and a retry that lands as a new note —
    /// the caret it was originally aimed at belongs to an editing session that is gone.
    @Test func theAbandonedRecordingIsRecoveredAsANewNote() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        let context = ModelContext(try ModelContainer(
            for: Note.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        let model = make(recorder, SlowService(), store, origin: .note)

        await model.begin()
        model.done()
        await settled(model)
        model.finishOnLeave()
        await settle()

        // Home, next: one recording to offer back, and it knows it came from a note.
        let recovered = try #require(store.recoverable())
        #expect(recovered.origin == .note)
        #expect(VoiceErrorCopy.recoveryNotice(for: recovered.origin) != nil)

        let recovery = VoiceCaptureModel(recovering: recovered,
                                         service: RecoveryService.succeeding,
                                         retention: store) { transcript in
            guard let note = QuickVoiceNote.make(from: transcript) else { return }
            context.insert(note)
        }
        recovery.retry()
        await settle()

        let notes = try context.fetch(FetchDescriptor<Note>())
        #expect(notes.count == 1, "the recovered recording did not become exactly one note")
        #expect(notes.first?.body == RecoveryService.text)
        #expect(store.remembered == nil)
        #expect(!FileManager.default.fileExists(atPath: recorder.startURL.path))
    }

    /// Retry after leaving is a *new* attempt, not a resumption of the abandoned one.
    @Test func retryAfterLeavingStartsAFreshAttempt() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: recorder.startURL) }
        let service = SlowService()
        let model = make(recorder, service, store)

        await model.begin()
        model.done()
        await settled(model)
        model.finishOnLeave()
        await settle()
        #expect(service.calls == 1)

        model.retry()
        await settle()
        #expect(service.calls == 2, "Retry reused the abandoned attempt instead of starting one")
    }

    /// Leaving is one event, even though two things report it.
    ///
    /// The editor finalizes the capture at the Back tap *and* on teardown, so this runs twice. It must
    /// mean the same thing both times: the first call started the upload — which `RULES.md` §2 requires
    /// to finish and insert into the note — and the second must not turn round and abandon it.
    @Test func leavingTwiceStillTranscribesIntoTheNote() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        var emitted: String?
        let model = make(recorder, RecoveryService.succeeding, store) { emitted = $0 }

        await model.begin()
        model.finishOnLeave()          // the Back tap
        model.finishOnLeave()          // EditorView.onDisappear, a moment later
        await settle()

        #expect(emitted == RecoveryService.text, "the words never reached the note")
        #expect(model.retainedRecording == nil, "a finished upload was abandoned and retained instead")
        #expect(store.remembered == nil)
    }

    /// And the same for the mid-upload case, from the other direction: two calls, one outcome.
    @Test func leavingTwiceMidTranscriptionRetainsExactlyOnce() async throws {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let recorder = RecoveryRecorder()
        recorder.startURL = try makeAudioFile()
        defer { try? FileManager.default.removeItem(at: recorder.startURL) }
        let model = make(recorder, SlowService(), store)

        await model.begin()
        model.done()
        await settled(model)
        let before = model.retainedRecording?.retainedAt
        model.finishOnLeave()
        let claimed = model.retainedRecording?.retainedAt
        model.finishOnLeave()
        await settle()

        #expect(before == nil)
        #expect(claimed != nil)
        #expect(model.retainedRecording?.retainedAt == claimed, "the second leave restamped the clock")
        #expect(store.remembered?.url == recorder.startURL)
    }

    /// Quick Voice is untouched by this: it has no note to navigate back to, and its own paths are
    /// unchanged. Leaving with nothing held is still just leaving.
    @Test func leavingWithNothingHeldIsStillHarmless() async {
        let (store, defaults, name) = makeStore()
        defer { defaults.removePersistentDomain(forName: name) }
        let model = make(RecoveryRecorder(), SlowService(), store, origin: .quickVoice)

        model.finishOnLeave()

        #expect(model.phase == .idle)
        #expect(store.remembered == nil)
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
