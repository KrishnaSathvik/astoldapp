import Foundation
import AVFoundation

/// What a capture does when the audio route changes underneath it — AirPods connecting or
/// disconnecting, a headset unplugged, the system moving the input (`docs/10-voice-v2.md` §14).
///
/// A pure decision, kept out of the recorder and out of the view, because the interesting part is a
/// policy question rather than an AVFoundation question: *may this recording keep going, or should it
/// be finished with the audio it already has?* Parsing the notification is three lines; getting that
/// answer wrong loses somebody's words.
///
/// Route **semantics**, never product names. "AirPods disconnected" reaches this type as an input
/// that went away, which is the same fact as a headset unplugged or a USB microphone removed.
enum AudioRouteChange {

    /// What happened to the route, in the only three shapes the decision depends on.
    enum Reason: Equatable {
        /// The input the recording was using went away.
        case inputDeviceLost
        /// Another input became available. The recording did not ask for it.
        case inputDeviceAdded
        /// A configuration change that leaves the input intact.
        case other

        /// The system's own reasons, folded onto the three above.
        init(_ reason: AVAudioSession.RouteChangeReason) {
            switch reason {
            case .oldDeviceUnavailable, .noSuitableRouteForCategory:
                self = .inputDeviceLost
            case .newDeviceAvailable:
                self = .inputDeviceAdded
            default:
                self = .other
            }
        }
    }

    enum Decision: Equatable {
        /// Stop cleanly and keep everything captured so far; it goes on to transcription exactly as
        /// **Done** would. Never a discard.
        case finishSafely
        /// Nothing to do — one continuous container, still being written.
        case keepRecording
    }

    /// The conservative policy `docs/10-voice-v2.md` §14 asks for.
    ///
    /// - Losing the active input finishes safely. iOS may well move the recording to the built-in
    ///   microphone without missing a sample, but "may well" is not something to bet a user's words
    ///   on, and a live waveform drawn over a dead input is worse than an honest stop. If the device
    ///   pass shows `AVAudioRecorder` surviving the transition with one valid container, this is the
    ///   one line that has to change.
    /// - A newly available device does **not** end the recording. Somebody speaking a thought must
    ///   not have their microphone switched mid-sentence because a case was opened nearby; a new
    ///   device is used naturally by the *next* recording.
    /// - No remaining input at all is unambiguous, whatever the notification's reason said: there is
    ///   nothing left to record with.
    static func decision(for reason: Reason, hasInput: Bool) -> Decision {
        guard hasInput else { return .finishSafely }
        return reason == .inputDeviceLost ? .finishSafely : .keepRecording
    }
}
