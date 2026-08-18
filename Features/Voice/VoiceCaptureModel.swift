import SwiftUI

/// Orchestrates a single voice capture: permission → record → transcribe → emit transcript.
/// Injected recorder + service keep the flow fully testable. See docs/04-voice-transcription.md.
@MainActor @Observable
final class VoiceCaptureModel {
    enum Phase: Equatable {
        case idle
        case permissionDenied
        case recording
        case transcribing
        case failed(TranscriptionError)
    }

    private(set) var phase: Phase = .idle
    private(set) var level: Float = 0

    private var recorder: AudioRecording
    private let service: TranscriptionService
    private let onTranscript: (String) -> Void

    private var recordedURL: URL?
    private var work: Task<Void, Never>?

    init(recorder: AudioRecording,
         service: TranscriptionService,
         onTranscript: @escaping (String) -> Void) {
        self.recorder = recorder
        self.service = service
        self.onTranscript = onTranscript
    }

    /// Ask for permission and start recording.
    func begin() async {
        guard await recorder.requestPermission() else { phase = .permissionDenied; return }
        do {
            // A call or Siri ends the recording for us — finish with what was captured rather than
            // silently dropping the user's words (docs/04-voice-transcription.md §7).
            recorder.onInterruption = { [weak self] in self?.done() }
            recordedURL = try recorder.start()
            phase = .recording
        } catch {
            phase = .failed(.serviceUnavailable)
        }
    }

    /// Stop recording and transcribe.
    func done() {
        guard phase == .recording else { return }
        guard let url = recorder.stop() else { phase = .failed(.noSpeech); return }
        recordedURL = url
        transcribe(url)
    }

    /// Abort the whole capture and delete the temporary audio.
    func cancel() {
        work?.cancel()
        recorder.cancel()
        recordedURL = nil
        phase = .idle
    }

    /// Retry transcription on the kept temporary file after a failure.
    func retry() {
        guard let url = recordedURL else { phase = .idle; return }
        transcribe(url)
    }

    /// Discard after a failure: delete the temporary file and reset.
    func discard() {
        work?.cancel()
        if let url = recordedURL { recorder.cleanup(url) }
        recordedURL = nil
        phase = .idle
    }

    func refreshLevel() { level = recorder.level }

    private func transcribe(_ url: URL) {
        phase = .transcribing
        work = Task { [service, onTranscript] in
            do {
                let result = try await service.transcribe(audioURL: url, requestID: UUID())
                guard !Task.isCancelled else { return }
                onTranscript(result.text)          // editor owns insertion
                recorder.cleanup(url)              // delete temp audio on success
                recordedURL = nil
                phase = .idle
            } catch is CancellationError {
                // left as-is; cancel()/discard() handle cleanup
            } catch let e as TranscriptionError {
                phase = .failed(e)                 // keep temp file for explicit retry
            } catch {
                phase = .failed(.serviceUnavailable)
            }
        }
    }
}
