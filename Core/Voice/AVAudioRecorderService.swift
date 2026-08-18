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
        return url
    }

    func stop() -> URL? {
        endInterruptionObservation()
        recorder?.stop()
        let url = currentURL
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return url
    }

    func cancel() {
        endInterruptionObservation()
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
    /// A route change (AirPods connecting/disconnecting) is deliberately *not* an interruption —
    /// AVAudioRecorder keeps recording on the new input.
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

    // MARK: - Abandoned temp audio

    /// Deletes recordings left behind by a crash or force-quit. Called once at launch so raw audio
    /// never lingers on disk beyond the capture it belongs to (RULES.md §3).
    static func purgeAbandonedRecordings(in directory: URL = FileManager.default.temporaryDirectory) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        else { return }
        for file in files where file.lastPathComponent.hasPrefix(tempPrefix) && file.pathExtension == "m4a" {
            try? fm.removeItem(at: file)
        }
    }
}
