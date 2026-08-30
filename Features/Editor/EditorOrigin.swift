import Foundation

/// Which screen the editor was pushed from — and therefore what its Back button *announces*.
///
/// The editor is opened from two places, Home and the calendar, and it is pushed onto whichever
/// navigation stack the reader is already standing in. So Back has always *gone* to the right screen;
/// what it *said* was wrong. A note opened from the calendar offered "‹ Notes", naming a screen the tap
/// does not lead to, which is a back button breaking the one promise a back button makes (fixed
/// 2026-08-25).
///
/// The visible word is gone entirely as of 2026-08-26 — every origin draws the chevron alone. What
/// survives here is the part a chevron cannot carry: the spoken destination. A sighted reader gets a
/// mark that means "back" on every iPhone; a VoiceOver reader gets the screen's name. `backTitle` and
/// a `.newNote` case both existed only to vary the visible word, and both went with it.
///
/// This changes a label and nothing else. No navigation, no state, no second path through the editor —
/// there is still one `EditorView` and one way in and out of it.
enum EditorOrigin: Hashable {
    /// Home — the note list. The default, because every caller that does not say otherwise came from
    /// there, and a new value here must never silently relabel an existing screen.
    case notes
    /// The calendar, with a day selected. Back returns to it with that day still chosen.
    case calendar

    init() { self = .notes }

    /// What a screen reader is told — now the *only* thing the button says.
    ///
    /// This is load-bearing precisely because the word is gone. A bare chevron conveys nothing at all
    /// to somebody who cannot see it, and "Back" alone does not say back to *what*. So the label names
    /// the screen the tap leads to, and it is the one place the origin still makes a difference
    /// (RULES.md §4).
    var backAccessibilityLabel: String {
        switch self {
        case .notes: return "Back to notes"
        case .calendar: return "Back to calendar"
        }
    }
}

/// A note plus the screen it was opened from — the single value a navigation stack pushes.
///
/// The origin travels *inside* the pushed item rather than in a `@State` beside it, and that is the
/// whole point of the type (2026-08-26). Holding it alongside looks equivalent and is not:
/// `navigationDestination(item:)` builds its destination from the view as it stood *before* the
/// transaction that set the item, so a sibling `@State` written in the same tick is read one push
/// stale. Home set one origin and the editor was handed another, every time, on the very first push
/// — the enum was right and the delivery was broken, which is why `EditorOrigin`'s own unit tests
/// never saw it. Kept after the visible label was dropped: the spoken destination rides the same
/// path, and it is the same path that was silently wrong once already.
///
/// Bundled into one item there is no second value to be stale: the closure is *given* the origin it
/// must render. `CalendarPage` never had the bug because it passes `.calendar` as a literal.
struct EditorRoute: Hashable {
    let note: Note
    let origin: EditorOrigin

    init(_ note: Note, from origin: EditorOrigin) {
        self.note = note
        self.origin = origin
    }
}
