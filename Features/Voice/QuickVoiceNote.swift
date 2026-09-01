import Foundation

/// The one place a Quick Voice capture becomes a `Note`.
///
/// **A capture is transient until it earns a note** (`RULES.md` §2, `docs/10-voice-v2.md` §3). No
/// `Note` is constructed or inserted when the microphone opens — only once a transcript with visible
/// text exists. Cancel, a denied microphone, no speech, a declined disclosure, and a transcription
/// failure therefore leave nothing behind at all, rather than leaving an empty draft for the purge to
/// find later. "Eventually swept" is not the standard: a note that flickers into the timeline and out
/// again is a bug the reader sees.
///
/// This is a free function rather than something the view does inline so the rule can be tested
/// without a view — the whole point of the phase.
enum QuickVoiceNote {

    /// Builds the note a successful capture earned, or `nil` when the transcript has nothing in it.
    ///
    /// The note is **not** inserted here; the caller owns the `ModelContext`. Nothing is returned for
    /// an empty transcript, so an insert is impossible in the one case it would be wrong.
    ///
    /// Emptiness is judged the same way the rest of the app judges it (`Note.isEmptyDraft`): on
    /// *visible* text, so a transcript of nothing but whitespace or a stray structure marker is not
    /// mistaken for content.
    ///
    /// **No title is generated** (`docs/10-voice-v2.md` §7). Inventing one would be a second
    /// interpretation layer over words the product promises to preserve. Home needs none: a titleless
    /// note is drawn as an excerpt with no title line at all, never as "Untitled" and never by
    /// promoting its first sentence into one (`RULES.md` §1, `NoteRowContent`). A spoken note and a
    /// typed one with no title are the same row — there is no voice badge and no separate shape.
    static func make(from transcript: String) -> Note? {
        let note = Note(title: nil, body: transcript)
        return note.isEmptyDraft ? nil : note
    }
}
