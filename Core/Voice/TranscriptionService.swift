import Foundation

/// Result of transcribing a recording. Detected languages are useful for QA, not persisted with the note.
struct TranscriptionResult: Sendable, Equatable {
    let text: String
    let detectedLanguages: [String]
}

/// Domain errors mapped to concise human copy by the UI — never raw provider errors (RULES.md §5).
enum TranscriptionError: Error, Equatable, Sendable {
    case microphonePermissionDenied
    case noSpeech
    case offline
    case requestTooLarge
    case rateLimited
    case serviceUnavailable
    case invalidResponse
    case cancelled
}

/// Transcribes a completed recording. The service never mutates the note — the editor owns insertion
/// (docs/04-voice-transcription.md §8, docs/05-architecture.md §13).
protocol TranscriptionService: Sendable {
    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult
}
