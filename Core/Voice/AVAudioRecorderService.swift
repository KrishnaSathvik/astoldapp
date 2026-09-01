import Foundation
import AVFoundation

/// Real recorder: AVAudioRecorder → temporary mono AAC `.m4a` with a random name in the app's
/// temp dir, file-protected. Temp audio never goes to Photos/Documents and is deleted on
/// cancel/cleanup (RULES.md §3, docs/04-voice-transcription.md §6–7).
@MainActor
final class AVAudioRecorderService: NSObject, AudioRecording {
    /// Prefix for every temporary recording, so an abandoned file is identifiable at launch.
    static let tempPrefix = "rec-"

    /// How long `finish()` will wait for the encoder to confirm it has closed the file.
    ///
    /// A **liveness** bound, not a settling delay, and the difference matters. Correctness here does
    /// not rest on this number: what makes the file safe to send is that it was *measured*
    /// afterwards, and an unmeasurable container is refused whether it arrived late or on time. This
    /// exists only so that a delegate callback that never comes — a class of AVFoundation failure
    /// nobody can rule out from here — leaves the user on a failure screen instead of on
    /// "Transcribing…" forever.
    static let finalizationDeadline: Duration = .seconds(3)

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?

    /// Resumed when the encoder confirms the file is closed. `finish()` waits on it.
    private var finalization: CheckedContinuation<Void, Never>?
    /// Whether the stop now in progress is one this class asked for. A delegate finish that arrives
    /// while this is false is the recorder stopping on its own, which is the whole point of Fix 1.
    private var isFinishing = false
    /// So an encode error followed by a finish callback reports one ending rather than two.
    private var hasReportedUnexpectedStop = false

    var onCaptureEnded: ((RecordingStop) -> Void)?

    var isCapturing: Bool { recorder?.isRecording ?? false }

    func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }

    func start() throws -> URL {
        let session = AVAudioSession.sharedInstance()
        // `.record` (not `.playAndRecord`): the app never plays audio back, and the narrower
        // category keeps AirPods out of the low-quality bidirectional call route.
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.tempPrefix)\(UUID().uuidString)")
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44_100.0,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        // The recorder now has somewhere to report to. Without this the app could not tell a
        // finished recording from a failed one, and an encoder that died mid-thought went on being
        // drawn as "Listening" with a live timer over it.
        recorder.delegate = self
        guard recorder.record() else { throw TranscriptionError.serviceUnavailable }

        // Protect the temp file at rest.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path
        )

        self.recorder = recorder
        self.currentURL = url
        isFinishing = false
        hasReportedUnexpectedStop = false
        observeInterruptions()
        observeRouteChanges()
        return url
    }

    /// `AVAudioRecorder.pause()` holds the file open, and `record()` continues writing into it — so a
    /// paused-and-resumed capture is one container whose duration is the audio actually recorded, which
    /// is what the relay measures and what `docs/10-voice-v2.md` §5 requires. Nothing is concatenated,
    /// because nothing is ever split.
    func pause() {
        recorder?.pause()
    }

    func resume() {
        _ = recorder?.record()
    }

    /// Close the recorder, wait for the encoder to say so, and measure what it left behind.
    ///
    /// The order is the invariant: **stop → confirmed → deactivate → measure → (caller) upload**.
    /// It used to be stop-and-return, with the audio session torn down in the same breath as the
    /// encoder was told to finish, and the file read by the uploader microseconds later. Nothing in
    /// that sequence ever established that the container was complete.
    func finish() async -> FinishedRecording? {
        endSessionObservation()
        guard let recorder, let url = currentURL else { return nil }

        // A recorder that has already stopped — an encode error, or the system taking it — has
        // already closed its file. There is nothing to wait for, and waiting would be waiting for a
        // callback that has been and gone.
        if recorder.isRecording {
            isFinishing = true
            await withCheckedContinuation { continuation in
                finalization = continuation
                recorder.stop()
                startFinalizationDeadline()
            }
        }

        self.recorder = nil
        isFinishing = false
        // Only now: deactivating the session while the encoder is still flushing is the ordering
        // most likely to truncate the container it is about to be asked for.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return await Self.measure(url)
    }

    func cancel() {
        endSessionObservation()
        isFinishing = true
        recorder?.stop()
        resolveFinalization()
        if let url = currentURL { cleanup(url) }
        recorder = nil
        currentURL = nil
        isFinishing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        if currentURL == url { currentURL = nil }
    }

    var level: Float {
        guard let recorder else { return 0 }
        recorder.updateMeters()
        // Map dBFS (~ -60...0) to 0...1.
        let power = recorder.averagePower(forChannel: 0)
        let clamped = max(-60, min(0, power))
        return (clamped + 60) / 60
    }

    // MARK: - Finalization

    /// Measure the finished container the same way the relay will.
    ///
    /// `assetSeconds == nil` means the file carries no usable duration — the moov box never landed,
    /// or nothing was ever encoded into it. That is not a recording, and the caller is expected to
    /// treat it as one that captured nothing rather than spend an upload learning the same thing.
    private static func measure(_ url: URL) async -> FinishedRecording {
        let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int
        let seconds = try? await AVURLAsset(url: url).load(.duration).seconds
        guard let seconds, seconds.isFinite, seconds > 0 else {
            return FinishedRecording(url: url, assetSeconds: nil, bytes: bytes)
        }
        return FinishedRecording(url: url, assetSeconds: seconds, bytes: bytes)
    }

    /// Bound the wait described on `finalizationDeadline`. Resolving early is safe: the measurement
    /// that follows is what decides whether the file may be sent.
    private func startFinalizationDeadline() {
        Task { [weak self] in
            try? await Task.sleep(for: Self.finalizationDeadline)
            self?.resolveFinalization()
        }
    }

    /// Resume the finalization wait exactly once.
    private func resolveFinalization() {
        guard let finalization else { return }
        self.finalization = nil
        finalization.resume()
    }

    /// The recorder stopped and nobody asked it to. Report it once, as its own kind of ending.
    private func reportUnexpectedStop() {
        guard !isFinishing, !hasReportedUnexpectedStop, recorder != nil else { return }
        hasReportedUnexpectedStop = true
        onCaptureEnded?(.unexpected)
    }

    // MARK: - Interruptions

    /// A phone call or Siri stops the recorder for us. Rather than losing what was already spoken,
    /// hand control back to the capture model so it can finish with the audio captured so far.
    ///
    /// Only `.began` is acted on. An interruption that has *ended* deliberately does nothing: the
    /// microphone is never reopened without the user asking for it (`docs/10-voice-v2.md` §14), and a
    /// capture that resumed itself after a phone call would be recording a room nobody meant to record.
    private func observeInterruptions() {
        endInterruptionObservation()
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
            MainActor.assumeIsolated {
                guard let self, self.recorder != nil else { return }
                self.onCaptureEnded?(.interrupted)
            }
        }
    }

    private func endInterruptionObservation() {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
    }

    // MARK: - Audio routes

    /// AirPods connecting or disconnecting, a headset unplugged, the system moving the input
    /// (`docs/10-voice-v2.md` §14).
    ///
    /// The policy is `AudioRouteChange`'s, not this method's: all this one does is read the
    /// notification, ask, and — where the answer is "check again once this has settled" — go and
    /// check. Losing the input the recording was using finishes the capture through the same path a
    /// phone call takes: the audio recorded so far is already on disk, and it goes on to
    /// transcription rather than being thrown away. Everything else is left alone, so one continuous
    /// container stays one continuous container.
    ///
    /// **The route is in transition while this notification is being delivered.** A snapshot of
    /// `currentRoute.inputs` taken here reports an empty list for an instant during changes the
    /// recording survives perfectly well, and treating that instant as proof the microphone is gone
    /// ends captures that had no reason to end. So an empty read is a question, not an answer.
    private func observeRouteChanges() {
        endRouteObservation()
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let system = raw.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:)) ?? .unknown
            let reason = AudioRouteChange.Reason(system)
            let hasInput = !AVAudioSession.sharedInstance().currentRoute.inputs.isEmpty
            MainActor.assumeIsolated {
                guard let self, self.recorder != nil else { return }
                switch AudioRouteChange.decision(for: reason, hasInput: hasInput) {
                case .keepRecording:
                    return
                case .finishSafely:
                    self.onCaptureEnded?(.interrupted)
                case .confirmInputLoss:
                    self.confirmInputLoss()
                }
            }
        }
    }

    /// Ask the session, not the transition, whether there is still a microphone.
    ///
    /// Two settled facts rather than one transient one, and either is enough to keep recording:
    ///
    /// - `isInputAvailable` is a property of the **session**, not a snapshot of a route mid-change.
    ///   It answers the question the empty route list only appeared to answer.
    /// - `recorder.isRecording` is the recording itself still being open. A recorder that AVFoundation
    ///   has actually torn down reports `false` here — and if it does, the delegate has already said
    ///   so through `reportUnexpectedStop()`, so this path does not need to guess about it either.
    ///
    /// Deliberately no delay and no retry loop. If the input is genuinely gone, both of these are
    /// already false; if it is not, waiting would only postpone the same answer.
    private func confirmInputLoss() {
        let session = AVAudioSession.sharedInstance()
        guard !session.isInputAvailable, !(recorder?.isRecording ?? false) else { return }
        onCaptureEnded?(.interrupted)
    }

    private func endRouteObservation() {
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        routeObserver = nil
    }

    /// Both observations end together: they are two halves of one question — is this recorder still
    /// listening? — and a stopped recorder must answer neither.
    private func endSessionObservation() {
        endInterruptionObservation()
        endRouteObservation()
    }

    // MARK: - Abandoned temp audio

    /// Deletes recordings left behind by a crash or force-quit. Called once at launch so raw audio
    /// never lingers on disk beyond the capture it belongs to (RULES.md §3).
    ///
    /// `keeping` names the recordings a live capture is still offering back through **Retry** — the
    /// only audio this sweep may spare, and only while it is inside `VoiceLimits.retryLifetime`. Past
    /// that, a retained recording is deleted exactly like an abandoned one: the 24 hours are a ceiling
    /// on how long audio may exist, not a promise to keep it (`docs/10-voice-v2.md` §13).
    ///
    /// At launch the list is empty, and deliberately so. Nothing in As Told can offer a recording back
    /// after the process has died — there is no recovered-recordings surface, and inventing one is not
    /// part of this phase — so every temporary recording found at launch is abandoned by definition.
    /// That is stricter than the 24-hour ceiling, which is the direction this rule is allowed to err in.
    static func purgeAbandonedRecordings(in directory: URL = FileManager.default.temporaryDirectory,
                                         now: Date = .now,
                                         keeping retained: [RetainedVoiceRecording] = []) {
        let fm = FileManager.default
        let spared = Set(
            retained.filter { !$0.hasExpired(at: now) }.map { $0.url.standardizedFileURL }
        )
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        for file in files where file.lastPathComponent.hasPrefix(tempPrefix) && file.pathExtension == "m4a" {
            guard !spared.contains(file.standardizedFileURL) else { continue }
            try? fm.removeItem(at: file)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

/// The recorder's own account of what happened to it.
///
/// Nothing observed these before, which is what allowed the two states this file now cannot be in:
/// a capture whose file was never confirmed closed before it was uploaded, and a capture whose
/// encoder had failed while the app went on drawing a live timer over it.
extension AVAudioRecorderService: AVAudioRecorderDelegate {

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder,
                                                     successfully flag: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            // The finish this class asked for: release `finish()` to go and measure the file.
            self.resolveFinalization()
            // A finish nobody asked for is the recorder ending the capture on its own.
            if !flag || !self.isFinishing { self.reportUnexpectedStop() }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder,
                                                      error: Error?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.resolveFinalization()
            self.reportUnexpectedStop()
        }
    }
}
