import Testing
import Foundation
@testable import Yourly

/// In-memory tip store. Mirrors `UserDefaultsVoiceStructureTip` without touching the shared domain,
/// so tests cannot leak state into each other or into the app.
private final class FakeTipStore: VoiceStructureTipStoring, @unchecked Sendable {
    private(set) var seen: Bool
    private(set) var markCount = 0

    init(seen: Bool = false) { self.seen = seen }

    var hasSeenVoiceStructureTip: Bool { seen }
    func markVoiceStructureTipSeen() { seen = true; markCount += 1 }
}

/// The tip's whole value is its timing. These tests are about *when* it may appear — the ordering
/// rules matter more than the card itself, because a tip shown at the wrong moment (after a failure,
/// after a declined disclosure) teaches nothing and interrupts someone who is already unhappy.
@MainActor
struct WritingEducationTests {

    @Test func firstSuccessfulOffDeviceTranscriptionShowsTheTip() {
        let store = FakeTipStore()
        let education = WritingEducation(store: store)
        #expect(!education.showsVoiceStructureTip)

        education.voiceTranscriptionSucceeded(sentOffDevice: true)
        #expect(education.showsVoiceStructureTip)
    }

    /// The tip teaches a round trip. The offline fake never made one, so it must not trigger it —
    /// otherwise an unconfigured build teaches voice structure off a canned transcript.
    @Test func aLocalServiceNeverTriggersTheTip() {
        let education = WritingEducation(store: FakeTipStore())
        education.voiceTranscriptionSucceeded(sentOffDevice: false)
        #expect(!education.showsVoiceStructureTip)
    }

    @Test func anAlreadySeenTipNeverReturns() {
        let education = WritingEducation(store: FakeTipStore(seen: true))
        education.voiceTranscriptionSucceeded(sentOffDevice: true)
        #expect(!education.showsVoiceStructureTip)
    }

    @Test func dismissingPersistsBeforeHiding() {
        let store = FakeTipStore()
        let education = WritingEducation(store: store)
        education.voiceTranscriptionSucceeded(sentOffDevice: true)

        education.dismissVoiceStructureTip()
        #expect(!education.showsVoiceStructureTip)
        #expect(store.seen, "dismissal must persist, or a relaunch resurrects the tip")
    }

    /// The second, third, and tenth successful transcription are silent.
    @Test func laterTranscriptionsDoNotShowItAgain() {
        let store = FakeTipStore()
        let education = WritingEducation(store: store)
        education.voiceTranscriptionSucceeded(sentOffDevice: true)
        education.dismissVoiceStructureTip()

        for _ in 0..<5 { education.voiceTranscriptionSucceeded(sentOffDevice: true) }
        #expect(!education.showsVoiceStructureTip)
        #expect(store.markCount == 1)
    }

    /// A fresh instance reading a store that was already marked — the relaunch case.
    @Test func persistenceSurvivesANewInstance() {
        let store = FakeTipStore()
        let first = WritingEducation(store: store)
        first.voiceTranscriptionSucceeded(sentOffDevice: true)
        first.dismissVoiceStructureTip()

        let afterRelaunch = WritingEducation(store: store)
        afterRelaunch.voiceTranscriptionSucceeded(sentOffDevice: true)
        #expect(!afterRelaunch.showsVoiceStructureTip)
    }

    @Test func userDefaultsStoreRoundTrips() {
        let suite = "writing-education-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserDefaultsVoiceStructureTip(defaults: defaults)
        #expect(!store.hasSeenVoiceStructureTip)
        store.markVoiceStructureTipSeen()
        #expect(store.hasSeenVoiceStructureTip)
        // A second instance over the same domain — what a relaunch actually does.
        #expect(UserDefaultsVoiceStructureTip(defaults: defaults).hasSeenVoiceStructureTip)
    }
}

/// The sequencing the tip depends on, asserted against `VoiceCaptureModel` itself rather than
/// restated: the tip hangs off `onTranscript`, so these prove the callback cannot fire on the paths
/// that must stay silent — a failure, a cancellation, or a disclosure the user never accepted.
@MainActor
private final class TipSequencingRecorder: AudioRecording {
    var startURL = URL(fileURLWithPath: "/tmp/tip-seq.m4a")
    var level: Float = 0
    var onInterruption: (() -> Void)?
    func requestPermission() async -> Bool { true }
    func start() throws -> URL { startURL }
    func stop() -> URL? { startURL }
    func cancel() {}
    func cleanup(_ url: URL) {}
}

private struct DecliningConsent: TranscriptionConsentStoring {
    var hasConsented: Bool { false }
    func grant() {}
}

private struct FailingService: TranscriptionService {
    var sendsAudioOffDevice: Bool { true }
    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        throw TranscriptionError.serviceUnavailable
    }
}

@MainActor
struct VoiceTipSequencingTests {

    /// A failed transcription must leave the tip unshown *and* unmarked, so it still has its one
    /// chance after a transcription that works.
    @Test func aFailedTranscriptionNeverReachesTheTip() async {
        let store = FakeTipStore()
        let education = WritingEducation(store: store)
        let model = VoiceCaptureModel(recorder: TipSequencingRecorder(),
                                      service: FailingService(),
                                      consent: AlwaysGrantedTranscriptionConsent()) { _ in
            education.voiceTranscriptionSucceeded(sentOffDevice: true)
        }
        await model.begin()
        model.done()
        while model.phase == .transcribing { await Task.yield() }

        #expect(model.phase == .failed(.serviceUnavailable))
        #expect(!education.showsVoiceStructureTip)
        #expect(!store.seen, "a failure must not spend the tip's one chance")
    }

    /// The disclosure comes first. While consent is pending nothing has been sent, so the tip must
    /// not appear — this is what stops two teaching surfaces from stacking on a first recording.
    @Test func pendingConsentShowsNoTip() async {
        let education = WritingEducation(store: FakeTipStore())
        let model = VoiceCaptureModel(recorder: TipSequencingRecorder(),
                                      service: FakeTranscriptionService(delay: .milliseconds(1)),
                                      consent: DecliningConsent()) { _ in
            education.voiceTranscriptionSucceeded(sentOffDevice: true)
        }
        await model.begin()
        model.done()

        #expect(model.phase == .needsConsent)
        #expect(!education.showsVoiceStructureTip)
    }

    /// Declining by walking away — the capture is cancelled from the consent state and nothing sends.
    @Test func cancellingAtConsentNeverShowsTheTip() async {
        let store = FakeTipStore()
        let education = WritingEducation(store: store)
        let model = VoiceCaptureModel(recorder: TipSequencingRecorder(),
                                      service: FakeTranscriptionService(delay: .milliseconds(1)),
                                      consent: DecliningConsent()) { _ in
            education.voiceTranscriptionSucceeded(sentOffDevice: true)
        }
        await model.begin()
        model.done()
        #expect(model.phase == .needsConsent)

        model.cancel()
        #expect(model.phase == .idle)
        #expect(!education.showsVoiceStructureTip)
        #expect(!store.seen)
    }
}
