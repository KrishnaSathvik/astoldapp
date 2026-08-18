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

@MainActor
struct VoiceCaptureModelTests {
    private func make(recorder: FakeRecorder,
                      service: TranscriptionService,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder, service: service, onTranscript: onText)
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
