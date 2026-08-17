import Foundation

/// Deterministic transcription for building/perfecting the voice UX without a backend (build plan
/// Phase 8). Returns a fixed Telugu+English sample, or a configured error, after a short delay.
/// Never touches the network.
struct FakeTranscriptionService: TranscriptionService {
    /// Fixed transcript demonstrating verbatim code-switching (matches the design reference).
    static let sampleText =
        "I was thinking maybe మనం Anchorage లో stay చేయుండా two nights Seward లో stay చేసు better ఉంటుంది."

    var result: Result<TranscriptionResult, TranscriptionError>
    var delay: Duration

    init(
        result: Result<TranscriptionResult, TranscriptionError> = .success(
            TranscriptionResult(text: FakeTranscriptionService.sampleText, detectedLanguages: ["te", "en"])
        ),
        delay: Duration = .milliseconds(1200)
    ) {
        self.result = result
        self.delay = delay
    }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        try? await Task.sleep(for: delay)
        try Task.checkCancellation()
        switch result {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}
