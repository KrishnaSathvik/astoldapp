import Foundation
import os

/// What a capture measured about itself, recorded in DEBUG so the next truncation is diagnosed
/// rather than reasoned about.
///
/// **Metadata only, and never in a shipping build.** The whole body is behind `#if DEBUG`, and every
/// field below is a number, an enum case, or a duration. No transcript, no note text, no audio, no
/// file path — a temporary file's name is random, but it is still a name for a specific recording,
/// and the rule this file lives under does not have a "but it is only DEBUG" clause (`RULES.md` §3).
///
/// The one comparison it exists to make is `recorded` against `asset`:
///
///     recorded=27.8  asset=27.6   →  the microphone was open for as long as the app believed
///     recorded=31.2  asset=6.4    →  the recorder died at 6.4s and nothing noticed until now
///
/// The relay already logs the duration it measures server-side (`transcription ok`), which catches
/// the same divergence one hop later. This catches it *before* the upload, which is the only place
/// it can be told apart from a transcription that came back short.
enum VoiceDiagnostics {

    /// A capture has finished and its file has been measured.
    static func captureFinished(origin: RetainedVoiceRecording.Origin,
                                ending: RecordingStop,
                                recorded: Duration,
                                finished: FinishedRecording) {
        #if DEBUG
        let recordedSeconds = Self.seconds(recorded)
        let asset = finished.assetSeconds
        logger.debug("""
            voice_capture_finished origin=\(String(describing: origin), privacy: .public) \
            ending=\(String(describing: ending), privacy: .public) \
            recorded=\(recordedSeconds, format: .fixed(precision: 2), privacy: .public) \
            asset=\(asset ?? -1, format: .fixed(precision: 2), privacy: .public) \
            bytes=\(finished.bytes ?? -1, privacy: .public) \
            drift=\(asset.map { recordedSeconds - $0 } ?? -1, format: .fixed(precision: 2), privacy: .public)
            """)
        #endif
    }

    /// A transcript came back. Its **length**, never a character of it.
    static func transcriptReceived(origin: RetainedVoiceRecording.Origin, characters: Int) {
        #if DEBUG
        logger.debug("""
            voice_transcript_received origin=\(String(describing: origin), privacy: .public) \
            chars=\(characters, privacy: .public)
            """)
        #endif
    }

    #if DEBUG
    private static let logger = Logger(subsystem: "com.astold.app", category: "voice")

    private static func seconds(_ duration: Duration) -> Double {
        let (whole, attoseconds) = duration.components
        return Double(whole) + Double(attoseconds) / 1e18
    }
    #endif
}
