import SwiftUI

/// App-lock state machine. See docs/05-architecture.md §18 and RULES.md §3.
///  - unlocked: content visible
///  - covered:  app not active; content hidden before the app-switcher snapshot
///  - locked:   app active but awaiting authentication
@MainActor @Observable
final class AppLockModel {
    enum Phase: Equatable { case unlocked, covered, locked }

    private(set) var phase: Phase
    var enabled: Bool { didSet { if !enabled { phase = .unlocked } } }

    private let authenticator: Authenticating
    private let reason = "Unlock your notes"
    /// Guards against a second prompt: the system authentication sheet itself makes the scene
    /// resign active and become active again, which re-enters `didBecomeActive()` mid-flight.
    private var isAuthenticating = false

    init(enabled: Bool, authenticator: Authenticating) {
        self.enabled = enabled
        self.authenticator = authenticator
        // Cold launch with the lock on: there is no prior `.covered` transition to escalate from,
        // so start locked rather than revealing notes before anyone authenticates.
        self.phase = enabled ? .locked : .unlocked
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

    /// The scene became active: anything but an already-unlocked session requires authentication.
    func didBecomeActive() async {
        guard enabled else { phase = .unlocked; return }
        guard phase != .unlocked else { return }
        phase = .locked
        await attemptUnlock()
    }

    /// Try to authenticate and reveal content. Stays locked on failure/cancel — never exposes notes.
    func attemptUnlock() async {
        guard enabled else { phase = .unlocked; return }
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        if await authenticator.authenticate(reason: reason) {
            phase = .unlocked
        } else {
            phase = .locked
        }
    }
}
