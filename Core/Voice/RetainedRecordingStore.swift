import Foundation

/// Remembers **the one** recording a failed capture kept, across navigation and across launches
/// (`docs/10-voice-v2.md` §13, decided 2026-08-28).
///
/// The rule it exists to keep: once useful audio has been recorded, As Told protects it until it
/// becomes text, the user deletes it, or the 24 hours run out. Leaving the note and the process
/// ending are none of those three, so neither may be what deletes it — and without something durable
/// remembering the file, the launch sweep has no way to tell a recording somebody can still retry
/// from one abandoned by a crash.
///
/// Deliberately the smallest thing that can do that: a **name**, a **date**, and where the capture
/// came from. No transcript, no title, no note reference, no duration, no list — one recording, and
/// two things the user may do with it. A second entry here is the `audio archive` `RULES.md` §7
/// excludes, arriving as a data model.
protocol RetainedRecordingStoring: Sendable {
    /// What is remembered, as remembered — without asking whether it is still valid.
    var remembered: RetainedVoiceRecording? { get }
    /// Remember this recording, replacing anything remembered before it. There is only ever one.
    func remember(_ recording: RetainedVoiceRecording)
    /// Forget it: transcribed, deleted, or expired.
    func forget()
}

extension RetainedRecordingStoring {
    /// The remembered recording if it can still be offered back, and nothing if it cannot — in which
    /// case the memory is cleared on the way out, because a pointer to audio that is gone or past its
    /// window is not a recording, it is a stale key.
    ///
    /// `directory` is where temporary audio lives *now*. It is a parameter rather than a constant so
    /// the check can be run against a test's own directory, and because the real one is not stable —
    /// see `UserDefaultsRetainedRecording`.
    func recoverable(at now: Date = .now,
                     in directory: URL = FileManager.default.temporaryDirectory) -> RetainedVoiceRecording? {
        guard let remembered else { return nil }
        let url = directory.appendingPathComponent(remembered.url.lastPathComponent)
        guard !remembered.hasExpired(at: now),
              FileManager.default.fileExists(atPath: url.path) else {
            forget()
            return nil
        }
        return RetainedVoiceRecording(url: url,
                                      retainedAt: remembered.retainedAt,
                                      origin: remembered.origin)
    }
}

/// `@unchecked Sendable` for the same reason as `UserDefaultsVoiceAllowance`: `UserDefaults` is
/// thread-safe but unmarked, and this type adds no mutable state of its own.
struct UserDefaultsRetainedRecording: RetainedRecordingStoring, @unchecked Sendable {
    static let nameKey = "retainedRecordingName"
    static let dateKey = "retainedRecordingRetainedAt"
    static let originKey = "retainedRecordingOrigin"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The **file name**, never the path.
    ///
    /// The temporary directory's path contains the app's own container identifier, and that changes
    /// between installs and updates. A stored absolute path therefore goes stale while the file it
    /// names is still perfectly there, and the recovery would quietly find nothing. `recoverable`
    /// resolves the name against wherever temporary audio lives now.
    var remembered: RetainedVoiceRecording? {
        guard let name = defaults.string(forKey: Self.nameKey), !name.isEmpty,
              defaults.object(forKey: Self.dateKey) != nil else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let origin = defaults.string(forKey: Self.originKey)
            .flatMap(RetainedVoiceRecording.Origin.init(rawValue:)) ?? .quickVoice
        return RetainedVoiceRecording(
            url: url,
            retainedAt: Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Self.dateKey)),
            origin: origin
        )
    }

    func remember(_ recording: RetainedVoiceRecording) {
        defaults.set(recording.url.lastPathComponent, forKey: Self.nameKey)
        defaults.set(recording.retainedAt.timeIntervalSinceReferenceDate, forKey: Self.dateKey)
        defaults.set(recording.origin.rawValue, forKey: Self.originKey)
    }

    func forget() {
        defaults.removeObject(forKey: Self.nameKey)
        defaults.removeObject(forKey: Self.dateKey)
        defaults.removeObject(forKey: Self.originKey)
    }
}

/// Remembers nothing. For captures that keep their audio on the device anyway — the local fake
/// service — and for tests that are not about recovery.
struct NoRetainedRecordingStore: RetainedRecordingStoring {
    var remembered: RetainedVoiceRecording? { nil }
    func remember(_ recording: RetainedVoiceRecording) {}
    func forget() {}
}

/// The "recorder" behind a recovered recording.
///
/// A recording being offered back after the app closed has no microphone behind it — the one that
/// made it belonged to a process that has ended. The only thing left to do to the file is send it or
/// delete it, so that is all this does. Everything else is a no-op rather than a fatal error: a
/// recovered capture reaches none of those paths, and a stub that crashes to prove a point is a
/// crash in somebody's notes app.
@MainActor
final class RecoveredRecordingFile: AudioRecording {
    var level: Float { 0 }
    var onCaptureEnded: ((RecordingStop) -> Void)?

    /// Nothing is open, so nothing can stop.
    var isCapturing: Bool { false }

    /// There is no microphone to ask for.
    func requestPermission() async -> Bool { false }
    func start() throws -> URL { throw TranscriptionError.serviceUnavailable }
    func pause() {}
    func resume() {}
    func finish() async -> FinishedRecording? { nil }
    func cancel() {}

    /// The one thing a recovered recording's file can still have done to it, other than being sent.
    func cleanup(_ url: URL) { try? FileManager.default.removeItem(at: url) }
}
