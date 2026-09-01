import Foundation

/// Why a capture stopped listening.
///
/// The distinction this type exists to make is **intent**. A capture that ends because somebody
/// decided it should — Done, Back, the app going to the background, the five-minute cap — has
/// captured the whole of what was said, and the transcript that follows is the complete thought. A
/// capture that ends because the recorder died has not, and presenting the two identically is how an
/// app quietly keeps five seconds of a thirty-second thought and reports success
/// (`docs/10-voice-v2.md` §14: *say what happened*).
///
/// It is deliberately three cases and not a boolean. `interrupted` behaves like `userFinished` today
/// — a call or a lost microphone finishes safely and transcribes what was captured, which is the
/// locked behavior (`RULES.md` §2) — but it is a different fact about the world, and the moment they
/// share a case is the moment that difference stops being available to anybody who needs it.
enum RecordingStop: Equatable {
    /// An ending somebody chose: Done, leaving the surface, backgrounding, or the duration cap.
    case userFinished
    /// The system took the microphone: a call, Siri, or an input that is genuinely gone. Spec'd,
    /// expected, and never a discard — the audio recorded so far goes on to transcription.
    case interrupted
    /// The recorder stopped without being asked — an encoder failure, or a finish nobody requested.
    /// The audio up to that point is real and MUST be kept; what is *not* true is that it is all of
    /// what the user said.
    case unexpected
}

/// A closed, finalized recording, and what could be measured about it.
///
/// Returned only once the recorder has confirmed it is finished, which is what makes the numbers
/// mean anything: a duration read off a container that is still being written is not a measurement,
/// it is a guess that happens to parse.
///
/// `assetSeconds` is the **file's** duration, deliberately separate from `RecordedDuration`'s count
/// of how long the microphone was open. The two agreeing is the invariant that says a capture worked;
/// the two disagreeing is the single most useful fact about a capture that did not, and there is no
/// way to notice the disagreement without measuring both.
struct FinishedRecording: Equatable {
    let url: URL
    /// Duration measured from the finalized container, or `nil` when it could not be established.
    /// `nil` means the file is not transcribable — the relay measures the same way and refuses what
    /// it cannot measure (`transcription-service/src/media/audioDuration.ts`), so sending it would
    /// spend a round trip to be told what is already known here.
    let assetSeconds: Double?
    /// Size on disk. Metadata only, for diagnostics; nothing decides anything by it.
    let bytes: Int?

    /// Whether there is measurable audio here at all.
    var isTranscribable: Bool {
        guard let assetSeconds else { return false }
        return assetSeconds > 0
    }
}
