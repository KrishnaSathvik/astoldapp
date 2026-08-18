import Foundation
import Testing
@testable import Yourly

private struct MockAuthenticator: Authenticating {
    let result: Bool
    func authenticate(reason: String) async -> Bool { result }
}

/// Answers a scripted sequence, so a test can unlock a session first and then fail a later attempt.
private final class ScriptedAuthenticator: Authenticating, @unchecked Sendable {
    private let mutex = NSLock()
    private var results: [Bool]

    init(_ results: [Bool]) { self.results = results }

    func authenticate(reason: String) async -> Bool {
        mutex.withLock { results.isEmpty ? false : results.removeFirst() }
    }
}

/// Mimics the real system sheet: presenting it makes the scene resign active and become active
/// again while `authenticate` is still in flight.
private final class SceneChurnAuthenticator: Authenticating, @unchecked Sendable {
    private let mutex = NSLock()
    private var _calls = 0
    var calls: Int { mutex.withLock { _calls } }
    nonisolated(unsafe) var duringPrompt: (@MainActor @Sendable () async -> Void)?

    func authenticate(reason: String) async -> Bool {
        let isFirst = mutex.withLock { _calls += 1; return _calls == 1 }
        if isFirst { await duringPrompt?() }   // only once, so a regression fails instead of hanging
        return true
    }
}

/// An enabled lock that has already been unlocked in this session — the warm, in-app state.
@MainActor
private func unlockedSession(_ authenticator: Authenticating) async -> AppLockModel {
    let model = AppLockModel(enabled: true, authenticator: authenticator)
    await model.attemptUnlock()
    #expect(model.phase == .unlocked)
    return model
}

@MainActor
struct AppLockStateTests {
    @Test func enableRequiresSuccessfulAuth() async {
        let model = AppLockModel(enabled: false, authenticator: MockAuthenticator(result: true))
        let ok = await model.enable()
        #expect(ok)
        #expect(model.enabled)
        #expect(model.phase == .unlocked)
    }

    @Test func enableFailsWhenAuthFails() async {
        let model = AppLockModel(enabled: false, authenticator: MockAuthenticator(result: false))
        let ok = await model.enable()
        #expect(!ok)
        #expect(!model.enabled)
    }

    @Test func resignActiveCoversWhenEnabled() async {
        let model = await unlockedSession(ScriptedAuthenticator([true]))
        model.willResignActive()
        #expect(model.phase == .covered)
    }

    @Test func resignActiveDoesNothingWhenDisabled() {
        let model = AppLockModel(enabled: false, authenticator: MockAuthenticator(result: true))
        model.willResignActive()
        #expect(model.phase == .unlocked)
    }

    @Test func becomeActiveUnlocksOnAuthSuccess() async {
        let model = await unlockedSession(ScriptedAuthenticator([true, true]))
        model.willResignActive()          // -> covered
        await model.didBecomeActive()      // auth succeeds -> unlocked
        #expect(model.phase == .unlocked)
    }

    @Test func becomeActiveStaysLockedOnAuthFailure() async {
        let model = await unlockedSession(ScriptedAuthenticator([true, false]))
        model.willResignActive()          // -> covered
        await model.didBecomeActive()      // auth fails -> locked, content never revealed
        #expect(model.phase == .locked)
    }

    @Test func disableUnlocks() async {
        let model = await unlockedSession(ScriptedAuthenticator([true]))
        model.willResignActive()
        model.disable()
        #expect(!model.enabled)
        #expect(model.phase == .unlocked)
    }
}

@MainActor
struct AppLockColdLaunchTests {
    /// Cold launch (app was terminated, or relaunched from Xcode) with the lock enabled:
    /// there is no prior `.covered` transition, so the model must start locked on its own.
    @Test func coldLaunchStartsLockedWhenEnabled() {
        let model = AppLockModel(enabled: true, authenticator: MockAuthenticator(result: true))
        #expect(model.phase == .locked)
    }

    @Test func coldLaunchStartsUnlockedWhenDisabled() {
        let model = AppLockModel(enabled: false, authenticator: MockAuthenticator(result: true))
        #expect(model.phase == .unlocked)
    }

    /// Becoming active from a cold-launch `.locked` phase must authenticate, not fall through.
    @Test func becomeActiveFromColdLaunchAuthenticates() async {
        let model = AppLockModel(enabled: true, authenticator: MockAuthenticator(result: true))
        await model.didBecomeActive()
        #expect(model.phase == .unlocked)
    }

    @Test func becomeActiveFromColdLaunchStaysLockedOnFailure() async {
        let model = AppLockModel(enabled: true, authenticator: MockAuthenticator(result: false))
        await model.didBecomeActive()
        #expect(model.phase == .locked)
    }

    /// The system sheet churns the scene while the prompt is up; that must not stack a second prompt.
    @Test func systemSheetSceneChurnDoesNotPromptTwice() async {
        let authenticator = SceneChurnAuthenticator()
        let model = AppLockModel(enabled: true, authenticator: authenticator)
        authenticator.duringPrompt = { @MainActor [weak model] in
            guard let model else { return }
            model.willResignActive()
            await model.didBecomeActive()
        }
        await model.attemptUnlock()
        #expect(authenticator.calls == 1)
        #expect(model.phase == .unlocked)
    }
}
