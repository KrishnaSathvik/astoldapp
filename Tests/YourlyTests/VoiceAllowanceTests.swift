import Testing
import Foundation
@testable import Yourly

/// The monthly voice allowance as the app sees it (docs/04-voice-transcription.md §14). The relay
/// owns and enforces the limit; everything here is about the app refusing the *next* recording
/// before the microphone opens, so exactly one spoken thought is lost rather than one per attempt.
@MainActor
private final class FakeRecorder: AudioRecording {
    var startCount = 0
    var permissionAsked = false
    private(set) var cleaned: [URL] = []
    var level: Float = 0
    var onInterruption: (() -> Void)?

    func requestPermission() async -> Bool { permissionAsked = true; return true }
    func start() throws -> URL { startCount += 1; return URL(fileURLWithPath: "/tmp/allowance.m4a") }
    /// Pause/resume are not what these tests are about; they record the calls so a capture that
    /// pauses can still be driven through them.
    private(set) var pauses = 0
    private(set) var resumes = 0
    func pause() { pauses += 1 }
    func resume() { resumes += 1 }
    func stop() -> URL? { URL(fileURLWithPath: "/tmp/allowance.m4a") }
    func cancel() {}
    func cleanup(_ url: URL) { cleaned.append(url) }
}

/// Uploads (so consent and allowance both apply) and fails however the test asks.
private struct StubUploadingService: TranscriptionService {
    var sendsAudioOffDevice: Bool { true }
    var result: Result<TranscriptionResult, TranscriptionError>

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        try result.get()
    }
}

private struct GrantedConsent: TranscriptionConsentStoring {
    var hasConsented: Bool { true }
    func grant() {}
}

/// Records what the model asked it to remember. Not actor-isolated: `VoiceAllowanceStoring` is
/// `Sendable`, and these tests drive it from one task at a time.
private final class SpyAllowance: VoiceAllowanceStoring, @unchecked Sendable {
    var unavailableUntil: Date?
    private(set) var marked: [Date?] = []
    private(set) var cleared = 0

    init(unavailableUntil: Date? = nil) { self.unavailableUntil = unavailableUntil }

    func markUnavailable(until date: Date?) { marked.append(date); unavailableUntil = date }
    func clear() { cleared += 1; unavailableUntil = nil }
}

@MainActor
struct VoiceAllowanceStoreTests {
    private func store(_ now: Date = Date()) -> (UserDefaultsVoiceAllowance, UserDefaults) {
        let defaults = UserDefaults(suiteName: "allowance-\(UUID().uuidString)")!
        return (UserDefaultsVoiceAllowance(defaults: defaults, now: { now }), defaults)
    }

    @Test func startsAvailable() {
        let (allowance, _) = store()
        #expect(allowance.unavailableUntil == nil)
    }

    @Test func remembersAFutureReset() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let (allowance, _) = store(now)
        let reset = now.addingTimeInterval(86_400)

        allowance.markUnavailable(until: reset)

        #expect(allowance.unavailableUntil?.timeIntervalSince1970 == reset.timeIntervalSince1970)
    }

    /// A reset that has already passed is not a refusal. Reading it as one would keep voice off for
    /// someone whose allowance renewed while the app was closed.
    @Test func aPassedResetReadsAsAvailable() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let (allowance, _) = store(now)

        allowance.markUnavailable(until: now.addingTimeInterval(-1))

        #expect(allowance.unavailableUntil == nil)
    }

    /// The app must never invent a reset date, so a refusal without one is not remembered at all —
    /// the relay simply refuses again next time.
    @Test func aRefusalWithoutADateIsNotRemembered() {
        let (allowance, _) = store()
        allowance.markUnavailable(until: nil)
        #expect(allowance.unavailableUntil == nil)
    }

    @Test func clearingForgetsTheRefusal() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let (allowance, _) = store(now)
        allowance.markUnavailable(until: now.addingTimeInterval(86_400))

        allowance.clear()

        #expect(allowance.unavailableUntil == nil)
    }

    /// It holds a date and nothing else — no counter, no minutes remaining. A number kept here is a
    /// number the interface eventually shows, and there is no usage meter in V1 (RULES.md §1).
    @Test func storesOnlyOneValue() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let (allowance, defaults) = store(now)

        allowance.markUnavailable(until: now.addingTimeInterval(86_400))

        let written = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("voiceAllowance") }
        #expect(written == [UserDefaultsVoiceAllowance.key])
    }
}

@MainActor
struct VoiceAllowanceCaptureTests {
    private func make(recorder: FakeRecorder,
                      service: TranscriptionService,
                      allowance: VoiceAllowanceStoring,
                      onText: @escaping (String) -> Void = { _ in }) -> VoiceCaptureModel {
        VoiceCaptureModel(recorder: recorder,
                          service: service,
                          consent: GrantedConsent(),
                          allowance: allowance,
                          onTranscript: onText)
    }

    /// The whole reason the app remembers anything: at the ceiling, tapping the microphone must not
    /// take a thought it cannot transcribe.
    @Test func refusesBeforeOpeningTheMicrophone() async {
        let reset = Date().addingTimeInterval(86_400)
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: StubUploadingService(result: .failure(.serviceUnavailable)),
                         allowance: SpyAllowance(unavailableUntil: reset))

        await model.begin()

        #expect(model.phase == .failed(.monthlyLimitReached(resetsAt: reset)))
        #expect(recorder.startCount == 0)
        #expect(recorder.permissionAsked == false) // no permission prompt for a refusal either
    }

    @Test func recordsNormallyWhileUnderTheCeiling() async {
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: StubUploadingService(result: .failure(.serviceUnavailable)),
                         allowance: SpyAllowance(unavailableUntil: nil))

        await model.begin()

        #expect(model.phase == .recording)
        #expect(recorder.startCount == 1)
    }

    @Test func remembersTheRelaysRefusal() async {
        let reset = Date().addingTimeInterval(86_400)
        let allowance = SpyAllowance()
        let model = make(recorder: FakeRecorder(),
                         service: StubUploadingService(result: .failure(.monthlyLimitReached(resetsAt: reset))),
                         allowance: allowance)

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .failed(.monthlyLimitReached(resetsAt: reset)))
        #expect(allowance.marked == [reset])
    }

    /// Only the monthly refusal is remembered. A timeout or a dropped connection says nothing about
    /// the allowance, and gating voice on one would be inventing a limit the relay never set.
    @Test func doesNotRememberOtherFailures() async {
        let allowance = SpyAllowance()
        let model = make(recorder: FakeRecorder(),
                         service: StubUploadingService(result: .failure(.timedOut)),
                         allowance: allowance)

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(allowance.marked.isEmpty)
    }

    /// The crossing recording succeeds *and* tells the app the allowance is spent, so the next tap
    /// can be refused locally. Nobody loses a spoken thought discovering where the ceiling was.
    @Test func aSuccessfulTranscriptThatSpendsTheAllowanceIsRemembered() async {
        let reset = Date().addingTimeInterval(86_400)
        let allowance = SpyAllowance()
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: StubUploadingService(result: .success(
                            TranscriptionResult(text: "the whole thought",
                                                detectedLanguages: ["en"],
                                                allowanceExhaustedUntil: reset))),
                         allowance: allowance)

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .idle)          // the recording itself succeeded, normally
        #expect(allowance.marked == [reset])   // and the next one is already accounted for
        #expect(allowance.cleared == 0)
    }

    /// The tap after the crossing recording never reaches the recorder.
    @Test func theNextTapAfterExhaustionIsRefusedLocally() async {
        let reset = Date().addingTimeInterval(86_400)
        let allowance = SpyAllowance()
        let recorder = FakeRecorder()
        let model = make(recorder: recorder,
                         service: StubUploadingService(result: .success(
                            TranscriptionResult(text: "the whole thought",
                                                detectedLanguages: ["en"],
                                                allowanceExhaustedUntil: reset))),
                         allowance: allowance)

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))
        #expect(recorder.startCount == 1)
        recorder.permissionAsked = false  // the first tap legitimately asked; watch the second

        await model.begin()   // the next microphone tap

        #expect(model.phase == .failed(.monthlyLimitReached(resetsAt: reset)))
        #expect(recorder.startCount == 1)          // never started
        #expect(recorder.permissionAsked == false) // and never even asked again
    }

    /// A successful transcription with room left says nothing, and must not leave state behind.
    @Test func aSuccessfulTranscriptWithRoomLeftRemembersNothing() async {
        let allowance = SpyAllowance()
        let model = make(recorder: FakeRecorder(),
                         service: StubUploadingService(result: .success(
                            TranscriptionResult(text: "hello", detectedLanguages: ["en"]))),
                         allowance: allowance)

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(allowance.marked.isEmpty)
        #expect(allowance.unavailableUntil == nil)
    }

    @Test func aSuccessfulTranscriptForgetsAnyRefusal() async {
        let allowance = SpyAllowance()
        let model = make(recorder: FakeRecorder(),
                         service: StubUploadingService(
                            result: .success(TranscriptionResult(text: "hello", detectedLanguages: ["en"]))),
                         allowance: allowance)

        await model.begin()
        model.done()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .idle)
        #expect(allowance.cleared == 1)
    }

    /// A local service never reaches the relay, so it can never spend the relay's allowance.
    @Test func aLocalServiceIsNeverGated() async {
        let recorder = FakeRecorder()
        let model = VoiceCaptureModel(recorder: recorder,
                                      service: FakeTranscriptionService(),
                                      onTranscript: { _ in })

        await model.begin()

        #expect(model.phase == .recording)
    }
}

struct VoiceAllowanceCopyTests {
    /// It is not a failure of this recording, and it must not read like one.
    @Test func onlyTheAllowanceGetsATitle() {
        #expect(RecordingPanel.title(for: .monthlyLimitReached(resetsAt: nil)) == "Voice will be back soon")
        #expect(RecordingPanel.title(for: .timedOut) == nil)
        #expect(RecordingPanel.title(for: .noSpeech) == nil)
    }

    @Test func namesTheDayVoiceComesBack() {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 1
        let reset = Calendar.current.date(from: components)!

        let message = RecordingPanel.allowanceMessage(resetsAt: reset)

        #expect(message.contains("You've used this month's included voice transcription."))
        #expect(message.contains(reset.formatted(.dateTime.month(.wide).day())))
        #expect(message.contains("keep writing normally"))
    }

    /// Without a date from the relay the sentence stops early rather than guessing one.
    @Test func saysNoDateWhenTheRelaySentNone() {
        let message = RecordingPanel.allowanceMessage(resetsAt: nil)

        #expect(message == "You've used this month's included voice transcription. You can keep writing normally.")
    }

    /// No usage meter ships (RULES.md §1), so the app is never handed the numbers to draw one:
    /// the result carries a transcript, its languages, and at most a date.
    @Test func theResultCarriesNoUsageFigures() {
        let exhausted = TranscriptionResult(text: "hi",
                                            detectedLanguages: ["en"],
                                            allowanceExhaustedUntil: Date())
        let mirror = Mirror(reflecting: exhausted)
        let fields = mirror.children.compactMap(\.label).sorted()

        #expect(fields == ["allowanceExhaustedUntil", "detectedLanguages", "text"])
    }

    /// The copy names when voice returns, never how much was used or how much is left. The reset
    /// date is the one number allowed to appear, and only because it is a date.
    @Test func theCopyQuotesNoUsageFigures() {
        for message in [RecordingPanel.allowanceMessage(resetsAt: Date()),
                        RecordingPanel.allowanceMessage(resetsAt: nil)] {
            for meter in ["minute", "remaining", "left", "used up", "of 60", "quota", "limit", "%"] {
                #expect(!message.localizedCaseInsensitiveContains(meter))
            }
        }
        // With no date there is no number at all.
        #expect(RecordingPanel.allowanceMessage(resetsAt: nil)
            .rangeOfCharacter(from: .decimalDigits) == nil)
    }

    /// No Pro tier exists, so no upsell may appear (RULES.md §1).
    @Test func neverOffersAnUpgrade() {
        let message = RecordingPanel.allowanceMessage(resetsAt: Date())
        for word in ["upgrade", "Pro", "subscribe", "buy", "purchase", "unlock"] {
            #expect(!message.localizedCaseInsensitiveContains(word))
        }
    }
}
