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

    /// Client-side mirror of the relay's duration limit. The relay is still the authority — this
    /// only spares the user from talking past a limit that would reject the upload anyway.
    private let maxRecordingDuration: Duration
    private var limitTask: Task<Void, Never>?

    init(recorder: AudioRecording,
         service: TranscriptionService,
         maxRecordingDuration: Duration = VoiceLimits.maxRecordingDuration,
         onTranscript: @escaping (String) -> Void) {
        self.recorder = recorder
        self.service = service
        self.maxRecordingDuration = maxRecordingDuration
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
            startLimitTimer()
        } catch {
            phase = .failed(.serviceUnavailable)
        }
    }

    /// Stop recording and transcribe.
    func done() {
        guard phase == .recording else { return }
        limitTask?.cancel()
        limitTask = nil
        guard let url = recorder.stop() else { phase = .failed(.noSpeech); return }
        recordedURL = url
        transcribe(url)
    }

    /// Abort the whole capture and delete the temporary audio.
    func cancel() {
        limitTask?.cancel()
        limitTask = nil
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
        limitTask?.cancel()
        limitTask = nil
        work?.cancel()
        if let url = recordedURL { recorder.cleanup(url) }
        recordedURL = nil
        phase = .idle
    }

    func refreshLevel() { level = recorder.level }

    /// Stop at the limit the way the user would: finish the recording and transcribe what was
    /// captured. The audio is never discarded — reaching the cap means the words are already said,
    /// and dropping them would be the one outcome worse than a rejected upload.
    private func startLimitTimer() {
        limitTask?.cancel()
        limitTask = Task { [maxRecordingDuration] in
            try? await Task.sleep(for: maxRecordingDuration)
            guard !Task.isCancelled, phase == .recording else { return }
            done()
        }
    }

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
