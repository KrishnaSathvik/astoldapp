import Foundation

/// Local memory of the relay's answer when an installation reaches its monthly voice allowance
/// (`docs/04-voice-transcription.md` §14).
///
/// The relay is the authority and the only place the allowance is enforced — this store never
/// decides anything, it only remembers what the relay already said so the *next* microphone tap can
/// be refused before a recording is made.
///
/// The relay reports exhaustion on the **successful** transcription that causes it
/// (`allowanceExhausted` + `resetsAt`), not by rejecting a later upload. So the recording that
/// reaches the ceiling still returns its words, and this store is what stops the one after it from
/// ever being spoken. Nothing is lost to the limit; without this, every attempt for the rest of the
/// month would take a thought and then discard it.
///
/// It stores a single date and nothing else — no usage, no counter, no minutes remaining. The relay
/// does not send those figures and this store could not hold them: there is no meter to drive, and a
/// number kept here would be a number the interface eventually shows (RULES.md §1).
protocol VoiceAllowanceStoring: Sendable {
    /// When voice becomes available again, or `nil` if it is available now.
    var unavailableUntil: Date? { get }
    /// Remember a refusal. A `nil` date is deliberately *not* remembered: the app must never invent
    /// a reset instant, so an answer without one simply leaves the gate open and lets the relay
    /// refuse again.
    func markUnavailable(until: Date?)
    /// Voice worked, so whatever was remembered is stale.
    func clear()
}

/// `@unchecked Sendable` for the same reason as `UserDefaultsTranscriptionConsent`: `UserDefaults`
/// is thread-safe but unmarked, and this type adds no mutable state of its own.
struct UserDefaultsVoiceAllowance: VoiceAllowanceStoring, @unchecked Sendable {
    static let key = "voiceAllowanceUnavailableUntil"

    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping @Sendable () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    var unavailableUntil: Date? {
        guard defaults.object(forKey: Self.key) != nil else { return nil }
        let stored = Date(timeIntervalSinceReferenceDate: defaults.double(forKey: Self.key))
        // A date that has passed is not a refusal any more. Reading it as one would keep voice off
        // for a user whose allowance renewed while the app was closed.
        return stored > now() ? stored : nil
    }

    func markUnavailable(until date: Date?) {
        guard let date else { return }
        defaults.set(date.timeIntervalSinceReferenceDate, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}

/// Never gates. For fake/local transcription, which has no relay and therefore no allowance.
struct AlwaysAvailableVoiceAllowance: VoiceAllowanceStoring {
    var unavailableUntil: Date? { nil }
    func markUnavailable(until date: Date?) {}
    func clear() {}
}
