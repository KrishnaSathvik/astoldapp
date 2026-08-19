import Foundation

/// One-time acknowledgement that a recording leaves the device for transcription.
///
/// The microphone permission covers *recording*; it does not cover *sending*. App Review Guideline
/// 5.1.2(i) requires disclosing where personal data is shared with third parties — "including with
/// third-party AI" — and obtaining explicit permission before doing so. Apps with an account get
/// this at sign-up; As Told deliberately has none (RULES.md §1), so the only honest place for it is
/// the moment before the first upload.
///
/// Asked once, after Done and before the audio is sent, and never again. Recording still works
/// while the answer is pending — the words are already captured, and the choice is only about
/// whether they leave.
protocol TranscriptionConsentStoring: Sendable {
    var hasConsented: Bool { get }
    func grant()
}

/// Local, on-device record of the answer. Nothing about the decision is transmitted.
///
/// `@unchecked Sendable` because `UserDefaults` is documented as thread-safe but is not marked
/// `Sendable`; this type adds no mutable state of its own.
struct UserDefaultsTranscriptionConsent: TranscriptionConsentStoring, @unchecked Sendable {
    static let key = "voiceTranscriptionConsent"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasConsented: Bool { defaults.bool(forKey: Self.key) }

    func grant() { defaults.set(true, forKey: Self.key) }
}

/// Always-granted store for services that never send audio anywhere — see
/// `TranscriptionService.sendsAudioOffDevice`. Disclosing a transfer that does not happen would be
/// its own inaccuracy.
struct AlwaysGrantedTranscriptionConsent: TranscriptionConsentStoring {
    var hasConsented: Bool { true }
    func grant() {}
}
