import Foundation
import AVFoundation

/// Real recorder: AVAudioRecorder → temporary mono AAC `.m4a` with a random name in the app's
/// temp dir, file-protected. Temp audio never goes to Photos/Documents and is deleted on
/// cancel/cleanup (RULES.md §3, docs/04-voice-transcription.md §6–7).
@MainActor
final class AVAudioRecorderService: NSObject, AudioRecording {
    /// Prefix for every temporary recording, so an abandoned file is identifiable at launch.
    static let tempPrefix = "rec-"

    private var recorder: AVAudioRecorder?
    private var currentURL: URL?
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?

    var onInterruption: (() -> Void)?

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
        guard recorder.record() else { throw TranscriptionError.serviceUnavailable }

        // Protect the temp file at rest.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path
        )

        self.recorder = recorder
        self.currentURL = url
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

    func stop() -> URL? {
        endSessionObservation()
        recorder?.stop()
        let url = currentURL
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return url
    }

    func cancel() {
        endSessionObservation()
        recorder?.stop()
        if let url = currentURL { cleanup(url) }
        recorder = nil
        currentURL = nil
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
                self.onInterruption?()
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
    /// notification and ask. Losing the input the recording was using finishes the capture through the
    /// same path a phone call takes — the audio recorded so far is already on disk, and it goes on to
    /// transcription rather than being thrown away. Everything else is left alone, so one continuous
    /// container stays one continuous container.
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
                guard AudioRouteChange.decision(for: reason, hasInput: hasInput) == .finishSafely
                else { return }
                self.onInterruption?()
            }
        }
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
