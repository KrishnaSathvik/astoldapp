import SwiftUI

/// App-lock state machine. See docs/05-architecture.md §18 and RULES.md §3.
///  - unlocked: content visible
///  - covered:  app not active; content hidden before the app-switcher snapshot
///  - locked:   app active but awaiting authentication
@MainActor @Observable
final class AppLockModel {
    enum Phase: Equatable { case unlocked, covered, locked }

    private(set) var phase: Phase = .unlocked
    var enabled: Bool { didSet { if !enabled { phase = .unlocked } } }

    private let authenticator: Authenticating
    private let reason = "Unlock your notes"

    init(enabled: Bool, authenticator: Authenticating) {
        self.enabled = enabled
        self.authenticator = authenticator
    }

    /// Turn the lock on — requires a successful authentication. Returns whether it was enabled.
    func enable() async -> Bool {
        guard await authenticator.authenticate(reason: reason) else { return false }
        enabled = true
        phase = .unlocked
        return true
    }

    func disable() {
        enabled = false
        phase = .unlocked
    }

    /// The scene is leaving the active state (inactive/background): cover content before the snapshot.
    func willResignActive() {
        guard enabled else { return }
        if phase == .unlocked { phase = .covered }
    }

    /// The scene became active: if we were covered, require authentication before revealing.
    func didBecomeActive() async {
        guard enabled else { phase = .unlocked; return }
        if phase == .covered {
            phase = .locked
            await attemptUnlock()
        }
    }

    /// Try to authenticate and reveal content. Stays locked on failure/cancel — never exposes notes.
    func attemptUnlock() async {
        guard enabled else { phase = .unlocked; return }
        if await authenticator.authenticate(reason: reason) {
            phase = .unlocked
        } else {
            phase = .locked
        }
    }
}
