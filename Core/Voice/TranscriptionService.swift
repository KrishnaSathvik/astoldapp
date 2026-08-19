import Foundation

/// Result of transcribing a recording. Detected languages are useful for QA, not persisted with the note.
struct TranscriptionResult: Sendable, Equatable {
    let text: String
    let detectedLanguages: [String]
}

/// The product's recording length limit.
///
/// The relay is the authority here — it measures the uploaded audio and rejects anything longer,
/// because transcription is billed per minute and a client-reported length would simply be a lie
/// worth telling (`transcription-service/src/media/audioDuration.ts`). This constant mirrors the
/// relay's `MAX_DURATION_SECONDS` so the app can stop at the same point rather than let someone
/// speak for fourteen minutes and only then be told no. Keep the two in step.
enum VoiceLimits {
    /// 10 minutes, matching the relay default.
    static let maxRecordingSeconds = 600
    static var maxRecordingDuration: Duration { .seconds(maxRecordingSeconds) }
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
    case serviceUnavailable
    case invalidResponse
    case cancelled
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
