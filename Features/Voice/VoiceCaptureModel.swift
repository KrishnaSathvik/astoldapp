import SwiftUI

/// Orchestrates a single voice capture: permission → record → transcribe → emit transcript.
/// Injected recorder + service keep the flow fully testable. See docs/04-voice-transcription.md.
@MainActor @Observable
final class VoiceCaptureModel {
    enum Phase: Equatable {
        case idle
        case permissionDenied
        case recording
        /// Recording finished, audio held, waiting on the one-time disclosure before it is sent.
        /// Only ever reached once per install, and only when the service actually uploads
        /// (`TranscriptionConsent`).
        case needsConsent
        case transcribing
        case failed(TranscriptionError)
    }

    private(set) var phase: Phase = .idle
    private(set) var level: Float = 0

    private var recorder: AudioRecording
    private let service: TranscriptionService
    private let consent: TranscriptionConsentStoring
    private let allowance: VoiceAllowanceStoring
    private let onTranscript: (String) -> Void

    private var recordedURL: URL?
    private var work: Task<Void, Never>?

    /// Client-side mirror of the relay's duration limit. The relay is still the authority — this
    /// only spares the user from talking past a limit that would reject the upload anyway.
    private let maxRecordingDuration: Duration
    private var limitTask: Task<Void, Never>?

    init(recorder: AudioRecording,
         service: TranscriptionService,
         consent: TranscriptionConsentStoring? = nil,
         allowance: VoiceAllowanceStoring? = nil,
         maxRecordingDuration: Duration = VoiceLimits.maxRecordingDuration,
         onTranscript: @escaping (String) -> Void) {
        self.recorder = recorder
        self.service = service
        // A service that keeps the audio local has no transfer to disclose, so it is never gated.
        self.consent = consent ?? (service.sendsAudioOffDevice
            ? UserDefaultsTranscriptionConsent()
            : AlwaysGrantedTranscriptionConsent())
        // Likewise: audio that never reaches the relay never spends the relay's allowance.
        self.allowance = allowance ?? (service.sendsAudioOffDevice
            ? UserDefaultsVoiceAllowance()
            : AlwaysAvailableVoiceAllowance())
        self.maxRecordingDuration = maxRecordingDuration
        self.onTranscript = onTranscript
    }

    /// Ask for permission and start recording.
    func begin() async {
        // Refuse before the microphone opens, not after the upload. The relay already told us voice
        // is spent for this month; recording anyway would take a thought we then cannot transcribe.
        if let until = allowance.unavailableUntil {
            phase = .failed(.monthlyLimitReached(resetsAt: until))
            return
        }
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

    /// Stop recording, then transcribe — pausing once for the disclosure if the recording is about
    /// to leave the device for the first time.
    func done() {
        guard phase == .recording else { return }
        limitTask?.cancel()
        limitTask = nil
        guard let url = recorder.stop() else { phase = .failed(.noSpeech); return }
        recordedURL = url
        // The audio stays on disk while the question is open; nothing is sent until it is answered.
        guard consent.hasConsented else { phase = .needsConsent; return }
        transcribe(url)
    }

    /// The user accepted the disclosure: remember it and send the recording that is already waiting.
    func grantConsent() {
        guard phase == .needsConsent, let url = recordedURL else { return }
        consent.grant()
        transcribe(url)
    }

    /// Leaving the editor while a recording is running.
    ///
    /// Finishing, not cancelling. Backgrounding, a phone call, and the duration cap all already
    /// finish the capture and transcribe what was said; Back was the one exit that deleted it, which
    /// meant tapping it mid-sentence silently destroyed everything the user had spoken. The words are
    /// already said — the rule the rest of this type follows is that dropping them is the one outcome
    /// worse than a rejected upload.
    ///
    /// The single exception is a first recording whose disclosure has not been accepted. That audio
    /// cannot be sent, and it cannot be kept on disk with no UI left to ask (RULES.md §3), so it is
    /// the one case where leaving still discards.
    func finishOnLeave() {
        guard phase == .recording, consent.hasConsented else { cancel(); return }
        done()
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
                if let until = result.allowanceExhaustedUntil {
                    // This recording succeeded *and* spent the last of the month's allowance.
                    // Remembering that here is what makes the next microphone tap refuse before it
                    // opens, instead of taking a thought it cannot transcribe.
                    allowance.markUnavailable(until: until)
                } else {
                    allowance.clear()              // voice worked; any remembered refusal is stale
                }
                phase = .idle
            } catch is CancellationError {
                // left as-is; cancel()/discard() handle cleanup
            } catch let e as TranscriptionError {
                if case .monthlyLimitReached(let resetsAt) = e {
                    // The one recording that crosses the ceiling is lost; remembering the date is
                    // what stops the one after it from being lost too.
                    allowance.markUnavailable(until: resetsAt)
                }
                phase = .failed(e)                 // keep temp file for explicit retry
            } catch {
                phase = .failed(.serviceUnavailable)
            }
        }
    }
}
