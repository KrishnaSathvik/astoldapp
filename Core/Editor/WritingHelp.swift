import Foundation

// Discoverability for structured writing. As Told has no formatting toolbar and never will
// (RULES.md §1, §4), so the capability has to be learnable some other way: a transient hint on an
// empty note, a contextual reference while editing, and one voice tip after the first successful
// transcription. Reference only — nothing here applies a structure. Applying one stays with typing,
// `DocumentAction`, and `VoiceStructureParser`.

/// The content of the writing-help reference, derived from the implementation rather than restated.
///
/// Both lists come from the code that actually does the work — `BlockKind.marker` and
/// `VoiceStructureParser.vocabulary` — so help cannot drift from behavior. Change a marker and this
/// sheet changes with it; add a voice phrase without teaching it and `WritingHelpTests` fails.
enum WritingHelp {
    struct Marker: Identifiable, Equatable {
        /// The literal characters to type, trailing space included — the space is part of the marker
        /// and a reader who omits it gets plain text, so it must be shown.
        let marker: String
        let name: String
        var id: String { marker }
    }

    /// What to type, in the order a writer meets it: structure of the page, then lists.
    static let typingMarkers: [Marker] = [
        Marker(marker: BlockKind.heading.marker, name: "Heading"),
        Marker(marker: BlockKind.subheading.marker, name: "Subheading"),
        Marker(marker: BlockKind.bullet.marker, name: "Bullet list"),
        Marker(marker: BlockKind.numbered(1).marker, name: "Numbered list"),
        Marker(marker: BlockKind.checklist(checked: false).marker, name: "Checklist"),
    ]

    struct VoiceExample: Identifiable, Equatable {
        let task: String
        /// Said aloud, exactly as it would be spoken. `WritingHelpTests` runs every one of these
        /// through `VoiceStructureParser`, so an example that would not actually work fails the build.
        let utterance: String
        var id: String { task }
    }

    /// Voice taught by example rather than by dictionary. Nine commands listed cold teach nobody what
    /// a sentence containing them sounds like; three real utterances do, and the vocabulary stays
    /// underneath for reference.
    static let voiceExamples: [VoiceExample] = [
        VoiceExample(task: "Make a heading", utterance: "Heading. Alaska plans."),
        VoiceExample(task: "Make a list",
                     utterance: "Bullet list. Anchorage. Next item. Seward. End list."),
        VoiceExample(task: "Make a checklist",
                     utterance: "Checklist. Book hotel. Next item. Rent car."),
    ]

    /// What to say. The full vocabulary lives here and only here; the one-time voice tip deliberately
    /// shows two examples instead, because nine commands out of context teaches nobody.
    static let voiceCommands = VoiceStructureParser.vocabulary

    /// The line that states the product rule, in both surfaces. Structure is never inferred from
    /// content — it happens because the writer asked (RULES.md §2).
    static let structurePromise =
        "As Told only adds structure when you ask. Otherwise your words stay as written or spoken."

    /// The faint hint under "Start writing…" on an empty note. Deliberately three markers, not five:
    /// it is a nudge that the syntax exists, and the `?` reference is where the rest lives.
    ///
    /// Shown as marker/name pairs rather than a sentence, because the trailing space is part of the
    /// marker and a reader who omits it gets plain text. Prose with the markers quoted inline hid
    /// exactly the character that matters; the view renders `marker` monospaced, the same treatment
    /// `WritingHelpSheet` already uses, so the space occupies real width.
    static let emptyNoteHintMarkers: [Marker] = [
        Marker(marker: BlockKind.heading.marker, name: "heading"),
        Marker(marker: BlockKind.bullet.marker, name: "list"),
        Marker(marker: BlockKind.checklist(checked: false).marker, name: "checklist"),
    ]

    /// Introduces the markers above. Kept separate so no marker is ever embedded in prose.
    static let emptyNoteHintLead = "Type a marker to add structure:"
}

/// Whether the one-time voice-structure tip has been shown. Local only — nothing about it is sent.
protocol VoiceStructureTipStoring: Sendable {
    var hasSeenVoiceStructureTip: Bool { get }
    func markVoiceStructureTipSeen()
}

/// `@unchecked Sendable` for the same reason as `UserDefaultsTranscriptionConsent`: `UserDefaults` is
/// documented thread-safe but unmarked, and this type adds no mutable state of its own.
struct UserDefaultsVoiceStructureTip: VoiceStructureTipStoring, @unchecked Sendable {
    static let key = "voiceStructureTipSeen"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasSeenVoiceStructureTip: Bool { defaults.bool(forKey: Self.key) }

    func markVoiceStructureTipSeen() { defaults.set(true, forKey: Self.key) }
}

/// Decides when the one-time voice tip appears, kept out of the view so the sequencing is testable.
///
/// The ordering that matters: the tip follows a **successful** transcription, never a request to
/// transcribe. A failure, a cancelled capture, or a declined disclosure must all leave the tip
/// unshown — someone whose first recording failed has learned nothing yet, and teaching them voice
/// commands at that moment would be answering a question they did not ask.
@MainActor @Observable
final class WritingEducation {
    private let store: VoiceStructureTipStoring

    /// Drives the tip's presentation. Set only from a completed transcription, never during a view
    /// update.
    private(set) var showsVoiceStructureTip = false

    init(store: VoiceStructureTipStoring = UserDefaultsVoiceStructureTip()) {
        self.store = store
    }

    /// A transcript arrived. `sentOffDevice` mirrors `TranscriptionService.sendsAudioOffDevice`: the
    /// fake local service is used in tests and on an unconfigured build, and teaching voice structure
    /// off the back of a canned transcript would be teaching it off something that never happened.
    func voiceTranscriptionSucceeded(sentOffDevice: Bool) {
        guard sentOffDevice, !store.hasSeenVoiceStructureTip else { return }
        showsVoiceStructureTip = true
    }

    /// Dismissed with "Got it" — persist first, so a relaunch mid-dismissal cannot resurrect it.
    func dismissVoiceStructureTip() {
        store.markVoiceStructureTipSeen()
        showsVoiceStructureTip = false
    }
}
