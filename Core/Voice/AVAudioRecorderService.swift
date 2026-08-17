import Foundation
import AVFoundation

/// Real recorder: AVAudioRecorder → temporary mono AAC `.m4a` with a random name in the app's
/// temp dir, file-protected. Temp audio never goes to Photos/Documents and is deleted on
/// cancel/cleanup (RULES.md §3, docs/04-voice-transcription.md §6–7).
@MainActor
final class AVAudioRecorderService: NSObject, AudioRecording {
    private var recorder: AVAudioRecorder?
    private var currentURL: URL?

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
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec-\(UUID().uuidString)")
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
        return url
    }

    func stop() -> URL? {
        recorder?.stop()
        let url = currentURL
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return url
    }

    func cancel() {
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
}
