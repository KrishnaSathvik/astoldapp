import Foundation

/// The one place a transcription failure becomes words.
///
/// Two surfaces now show these: the in-note `RecordingPanel` and the Home `QuickVoiceCaptureView`.
/// They are different presentations of the same capture (`docs/10-voice-v2.md` §1), so the sentences
/// live here rather than being written twice — a second copy is a second thing to keep in step, and
/// its first divergence is one screen telling the user their recording is safe while the other does
/// not. See `docs/04-voice-transcription.md` §12.
enum VoiceErrorCopy {

    /// Only the monthly allowance gets a title. It is the one failure that is not about *this*
    /// recording, and reading it as "something went wrong" would be the wrong thing to believe.
    static func title(for error: TranscriptionError) -> String? {
        if case .monthlyLimitReached = error { return "Voice will be back soon" }
        return nil
    }

    /// The sentence that stops "Couldn't transcribe" from reading as *your words are gone*.
    ///
    /// Shown under the failure's own message whenever the recording was actually kept, and never
    /// otherwise: a promise about audio that has already been deleted would be worse than saying
    /// nothing (`docs/10-voice-v2.md` §13). Plain and physical on purpose — *on this iPhone*, not
    /// "cached" or "queued", because nothing about a retained recording is on its way anywhere.
    static let retainedNotice = "Your recording is still on this iPhone."

    /// The one management affordance a retained recording has. Named for what it does, not "Discard":
    /// the user is deleting audio, and the word should say so.
    static let deleteRecordingLabel = "Delete Recording"

    /// What the recovery surface says when a recording has outlived the screen it failed on — after
    /// Back, or after the app was closed and reopened (`docs/10-voice-v2.md` §13).
    ///
    /// Past tense and plainly ours: *we saved it*. The user did not ask for this and may not remember
    /// the failure, so the sentence has to explain its own existence before it asks for a decision.
    static let recoveryTitle = "We saved a recording that couldn't be transcribed."

    /// The one thing a recovered recording may have to warn about, said **before** the retry rather
    /// than discovered after it.
    ///
    /// A recording captured inside a note was aimed at a caret in an editing session that no longer
    /// exists, and the note may have been edited since. Guessing that offset would drop a transcript
    /// into the middle of a sentence, so the transcript becomes a new note instead — and the user is
    /// told so while they can still decide. Quick Voice always makes a new note, so saying it there
    /// would be noise.
    static func recoveryNotice(for origin: RetainedVoiceRecording.Origin) -> String? {
        origin == .note ? "This recording will be saved as a new note." : nil
    }

    /// What VoiceOver is told when a capture fails, or `nil` when it is told nothing.
    ///
    /// Spoken only where the recording survived, and it is the survival that earns the announcement:
    /// a reader who cannot see the screen has no other way to learn that four minutes of speech still
    /// exist. What is said is the failure and then that fact, in that order, because the reassurance
    /// only means something once you know what it is reassuring you about (`docs/10-voice-v2.md` §6).
    static func announcement(for error: TranscriptionError) -> String? {
        guard error.isRetryableVoiceFailure else { return nil }
        return "\(message(for: error)) \(retainedNotice)"
    }

    static func message(for error: TranscriptionError) -> String {
        switch error {
        case .offline: return "A connection is needed to transcribe this recording."
        // The reassurance that used to be pinned to this one error is now `retainedNotice`, shown
        // under every failure that actually kept the audio — and under none that did not.
        case .timedOut: return "The transcription service isn't responding."
        case .noSpeech: return "No speech was detected."
        case .rateLimited: return "Too many requests. Try again in a moment."
        case .requestTooLarge: return "That recording is too large to send."
        case .recordingTooLong(let maxSeconds): return lengthLimitMessage(maxSeconds: maxSeconds)
        case .monthlyLimitReached(let resetsAt): return allowanceMessage(resetsAt: resetsAt)
        default: return "Couldn't transcribe that recording."
        }
    }

    /// The date comes from the relay and is rendered in the reader's own time zone — the app never
    /// works out when the month turns over. Without one, the sentence simply stops early rather than
    /// guessing a date (`docs/04-voice-transcription.md` §12).
    static func allowanceMessage(resetsAt: Date?) -> String {
        let used = "You've used this month's included voice transcription."
        guard let resetsAt else { return "\(used) You can keep writing normally." }
        let day = resetsAt.formatted(.dateTime.month(.wide).day())
        return "\(used) You can keep writing normally, and voice will be available again on \(day)."
    }

    /// "Recordings can be up to 5 minutes." — stated in the relay's units, not a hard-coded number,
    /// so changing the server limit changes the copy with it.
    static func lengthLimitMessage(maxSeconds: Int) -> String {
        let minutes = maxSeconds / 60
        guard minutes >= 1, maxSeconds % 60 == 0 else {
            return "Recordings can be up to \(maxSeconds) seconds."
        }
        return "Recordings can be up to \(minutes) minute\(minutes == 1 ? "" : "s")."
    }

    /// The two labels are two different verbs, and Phase 2B made the difference load-bearing.
    ///
    /// **Retry** sends the recording that is still on the iPhone. **Try Again** opens the microphone,
    /// because the failure it belongs to — no speech — deleted its audio, and there is nothing left to
    /// send a second time.
    static let retryLabel = "Retry"
    static let recordAgainLabel = "Try Again"
}
