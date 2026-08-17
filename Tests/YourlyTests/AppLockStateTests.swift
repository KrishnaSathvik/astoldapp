import Testing
@testable import Yourly

private struct MockAuthenticator: Authenticating {
    let result: Bool
    func authenticate(reason: String) async -> Bool { result }
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

    @Test func resignActiveCoversWhenEnabled() {
        let model = AppLockModel(enabled: true, authenticator: MockAuthenticator(result: true))
        model.willResignActive()
        #expect(model.phase == .covered)
    }

    @Test func resignActiveDoesNothingWhenDisabled() {
        let model = AppLockModel(enabled: false, authenticator: MockAuthenticator(result: true))
        model.willResignActive()
        #expect(model.phase == .unlocked)
    }

    @Test func becomeActiveUnlocksOnAuthSuccess() async {
        let model = AppLockModel(enabled: true, authenticator: MockAuthenticator(result: true))
        model.willResignActive()          // -> covered
        await model.didBecomeActive()      // auth succeeds -> unlocked
        #expect(model.phase == .unlocked)
    }

    @Test func becomeActiveStaysLockedOnAuthFailure() async {
        let model = AppLockModel(enabled: true, authenticator: MockAuthenticator(result: false))
        model.willResignActive()          // -> covered
        await model.didBecomeActive()      // auth fails -> locked, content never revealed
        #expect(model.phase == .locked)
    }

    @Test func disableUnlocks() {
        let model = AppLockModel(enabled: true, authenticator: MockAuthenticator(result: false))
        model.willResignActive()
        model.disable()
        #expect(!model.enabled)
        #expect(model.phase == .unlocked)
    }
}
