import Foundation

// Reference content for structured writing. Structure is applied three ways — the Style menu, a
// typed marker, a spoken command — and this file is none of them: it is what the writing-help sheet
// shows, plus the one voice tip after a first successful transcription. Reference only; applying a
// structure stays with `BlockStyle`, `DocumentAction`, and `VoiceStructureParser`.
//
// The empty note used to carry a marker cheat-sheet from here too. It went when the Style menu
// landed (RULES.md §7): teaching syntax before the first word was the price of having no control,
// and the shortcuts now live one tap inside the menu, for writers who go looking.

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
