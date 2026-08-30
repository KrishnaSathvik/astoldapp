import Foundation

/// The one recording a failed capture is allowed to keep, and the clock it is kept against
/// (`docs/10-voice-v2.md` §13, `RULES.md` §2).
///
/// It exists so that this sequence is impossible:
///
///     speak for four minutes  →  network error  →  gone
///
/// Deliberately three values and no more. A retained recording is a *temporary file with a deadline*,
/// not a record in a library: there is no title, no duration, no note reference, no play count, and
/// nothing durable to list. The moment this type grows a second instance or a display name, As Told
/// has the audio archive `RULES.md` §7 excludes, arriving through the back door.
///
/// The audio itself stays exactly where the capture put it — the app-controlled, file-protected,
/// randomly-named temporary location `AVAudioRecorderService` writes to. Retention changes how long
/// the file lives, never where it lives (`RULES.md` §3).
/// `Identifiable` only so one recording can be presented as one sheet. The identity is the file's
/// name — the same name the store remembers — and it is never shown to anybody.
struct RetainedVoiceRecording: Equatable, Sendable, Identifiable {
    var id: String { url.lastPathComponent }

    /// Where the capture came from. Remembered for exactly one reason: the copy on the recovery
    /// surface depends on it. A recording captured inside a note has to say, *before* the retry, that
    /// its transcript will arrive as a new note — the caret it was originally aimed at belonged to an
    /// editing session that no longer exists (`docs/10-voice-v2.md` §13).
    ///
    /// It is not a category the note keeps. Nothing downstream of the transcript knows this existed,
    /// because a voice-created note is an ordinary note (`RULES.md` §2).
    enum Origin: String, Equatable, Sendable {
        case quickVoice
        case note
    }

    /// The finished audio, still in the temporary location the recorder created it in.
    let url: URL
    /// When the retryable failure happened — the instant the 24 hours are measured from.
    let retainedAt: Date
    var origin: Origin = .quickVoice

    /// When this recording stops being offered back and becomes something to delete.
    /// `VoiceLimits.retryLifetime` after retention, and nothing in the interface ever draws this as a
    /// countdown: expiry is a storage rule, not a progress bar (`docs/10-voice-v2.md` §13).
    var expiresAt: Date {
        retainedAt.addingTimeInterval(TimeInterval(VoiceLimits.retryLifetimeSeconds))
    }

    /// How long the recording has been kept, in seconds, floored at zero.
    ///
    /// The floor is the same convention `RecordedDuration` uses for a segment: a clock that has moved
    /// backwards — a time-zone edit, an NTP correction — must not be read as a recording from the
    /// future. It is simply not old yet.
    func age(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(retainedAt))
    }

    /// Whether the retry lifetime has run out. The boundary is stated rather than left to whichever
    /// comparison was written first: at exactly 24 hours the recording is over.
    func hasExpired(at now: Date) -> Bool {
        age(at: now) >= TimeInterval(VoiceLimits.retryLifetimeSeconds)
    }
}
