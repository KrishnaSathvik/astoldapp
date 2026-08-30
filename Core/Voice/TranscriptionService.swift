import Foundation

/// Result of transcribing a recording. Detected languages are useful for QA, not persisted with the note.
struct TranscriptionResult: Sendable, Equatable {
    let text: String
    let detectedLanguages: [String]
    /// Set only when *this* transcription spent the last of the month's voice allowance, carrying
    /// the relay's own reset instant (`docs/04-voice-transcription.md` §14). It lets the app refuse
    /// the next microphone tap before the recorder opens, so the ceiling is never discovered by
    /// losing a spoken thought to it.
    ///
    /// A date or nothing — never a remaining-minutes figure. There is no usage meter in V1, and a
    /// number carried here is a number the interface eventually shows (RULES.md §1).
    var allowanceExhaustedUntil: Date?

    init(text: String, detectedLanguages: [String], allowanceExhaustedUntil: Date? = nil) {
        self.text = text
        self.detectedLanguages = detectedLanguages
        self.allowanceExhaustedUntil = allowanceExhaustedUntil
    }
}

/// The product's recording length limit.
///
/// The relay is the authority here — it measures the uploaded audio and rejects anything longer,
/// because transcription is billed per minute and a client-reported length would simply be a lie
/// worth telling (`transcription-service/src/media/audioDuration.ts`). This constant mirrors the
/// relay's `MAX_DURATION_SECONDS` so the app can stop at the same point rather than let someone
/// speak for fourteen minutes and only then be told no. Keep the two in step.
enum VoiceLimits {
    /// 5 minutes, matching the relay default. Roughly 650–800 spoken words — already a very large
    /// note entry. The number says what As Told is: you speak a thought into a note, you do not
    /// record a meeting (changed 2026-08-21 from 10 minutes).
    static let maxRecordingSeconds = 300
    static var maxRecordingDuration: Duration { .seconds(maxRecordingSeconds) }

    /// How long a recording kept after a retryable transcription failure may live before it is
    /// deleted unretried — **24 hours**, locked 2026-08-27 (`RULES.md` §2, `docs/10-voice-v2.md`
    /// §13, where the rule names this constant `voiceRetryLifetime`).
    ///
    /// Long enough for temporary network or service trouble to clear and for somebody to come back
    /// to it later the same day; short enough that As Told is never quietly accumulating audio. It
    /// lives here, beside the recording cap, because the alternative is the number appearing in a
    /// view — and a retention period written into a button is a retention period nobody can find.
    static let retryLifetimeSeconds = 24 * 60 * 60
    static var retryLifetime: Duration { .seconds(retryLifetimeSeconds) }
}

/// Domain errors mapped to concise human copy by the UI — never raw provider errors (RULES.md §5).
enum TranscriptionError: Error, Equatable, Sendable {
    case microphonePermissionDenied
    case noSpeech
    case offline
    /// The upload exceeded the relay's byte cap.
    case requestTooLarge
    /// The recording was longer than the product limit. Carries the relay's own limit so the copy
    /// follows the server's configuration instead of restating a number the app guessed.
    case recordingTooLong(maxSeconds: Int)
    case rateLimited
    /// The installation has used its monthly voice allowance
    /// (`docs/04-voice-transcription.md` §14). Distinct from `rateLimited` even though both arrive
    /// as `429`: one clears in seconds and the other in days, so they cannot share copy. Carries the
    /// relay's own reset instant — the app renders it, never computes it.
    case monthlyLimitReached(resetsAt: Date?)
    /// The relay took too long, or could not be reached at all. Distinct from `offline`: the device
    /// has a connection, the service is simply not answering — and distinct from the generic
    /// `serviceUnavailable`, because retrying in a moment is the useful advice.
    case timedOut
    case serviceUnavailable
    case invalidResponse
    case cancelled
}

extension TranscriptionError {
    /// Whether sending **this same recording** again could plausibly succeed — the one question that
    /// decides whether the audio survives the failure (`docs/10-voice-v2.md` §13, `RULES.md` §2).
    ///
    /// One classification, in one place, because the alternative is each surface deciding for itself
    /// and the two disagreeing about whether a user's words still exist. A retained recording is
    /// allowed **only** where this is `true`; everything else deletes its audio immediately, which is
    /// what keeps `RULES.md` §3's deletion contract intact rather than quietly widened.
    ///
    /// Classified by what the failure *means*, not by how transient the name sounds:
    ///
    /// - `offline`, `timedOut`, `rateLimited` — the connection or the moment was wrong, not the audio.
    /// - `serviceUnavailable` — also carries a rejected attestation, which re-registers and then works.
    /// - `invalidResponse` — the ambiguous one. It covers a garbled answer (retrying helps) as well as
    ///   a file the relay could not measure (it will not). Resolved in the recording's favour: the
    ///   cost of being wrong is one tap that fails, against deleting words somebody already spoke.
    /// - `noSpeech` — the relay heard the file. It will hear the same thing again.
    /// - `monthlyLimitReached`, `recordingTooLong`, `requestTooLarge` — a limit this audio cannot get
    ///   under by being sent a second time.
    /// - `microphonePermissionDenied`, `cancelled` — no completed recording exists to retry.
    var isRetryableVoiceFailure: Bool {
        switch self {
        case .offline, .timedOut, .rateLimited, .serviceUnavailable, .invalidResponse:
            return true
        case .noSpeech, .monthlyLimitReached, .recordingTooLong, .requestTooLarge,
             .microphonePermissionDenied, .cancelled:
            return false
        }
    }

    /// One mapping of URLSession transport failures, shared by every network hop in the voice flow
    /// (attestation handshake and the upload itself), so both report the same thing to the user.
    static func transport(_ error: URLError) -> TranscriptionError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            return .offline
        case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return .timedOut
        default:
            return .serviceUnavailable
        }
    }
}

/// Transcribes a completed recording. The service never mutates the note — the editor owns insertion
/// (docs/04-voice-transcription.md §8, docs/05-architecture.md §13).
protocol TranscriptionService: Sendable {
    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult

    /// Whether transcribing sends the recording off the device. Drives the one-time disclosure in
    /// `TranscriptionConsent` — a service that keeps the audio local has nothing to disclose.
    ///
    /// Defaults to `true` on purpose: a new service that forgets to answer shows the disclosure
    /// rather than silently skipping it.
    var sendsAudioOffDevice: Bool { get }
}

extension TranscriptionService {
    var sendsAudioOffDevice: Bool { true }
}
