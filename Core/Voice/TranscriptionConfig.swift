import Foundation

/// Chooses the transcription backend: the real relay when a base URL is configured, otherwise the
/// deterministic fake (local dev / no backend yet). The OpenAI key never lives in the app — only the
/// relay's base URL does. See docs/06-tech-stack.md §18 (configuration).
enum TranscriptionConfig {
    /// Base URL from `TranscribeBaseURL` in Info.plist, overridable in DEBUG via a launch argument
    /// or UserDefaults key `transcribeBaseURL`. Empty/missing → use the fake service.
    static var baseURL: URL? {
        if let override = UserDefaults.standard.string(forKey: "transcribeBaseURL"), !override.isEmpty {
            return URL(string: override)
        }
        guard let s = Bundle.main.object(forInfoDictionaryKey: "TranscribeBaseURL") as? String,
              !s.isEmpty else { return nil }
        return URL(string: s)
    }

    @MainActor
    static func makeService() -> TranscriptionService {
        if let baseURL { return makeRelayService(baseURL: baseURL) }
        return FakeTranscriptionService()
    }

    /// Relay client with App Attest attached. One `AppAttestClient` is shared by the service so the
    /// install registers once and every request carries a fresh assertion (RULES.md §3). On the
    /// Simulator and unsupported hardware the client yields no headers and the relay decides.
    static func makeRelayService(
        baseURL: URL,
        session: URLSession = .shared,
        keys: AppAttestKeyProviding = DeviceCheckAppAttestKeys(),
        storage: AppAttestKeyIDStorage = UserDefaultsAppAttestKeyIDStorage()
    ) -> RelayTranscriptionService {
        let attest = AppAttestClient(baseURL: baseURL, session: session, keys: keys, storage: storage)
        var service = RelayTranscriptionService(baseURL: baseURL, session: session)
        service.attestationHeaders = { _ in await attest.headers() }
        service.attestationRejected = { await attest.invalidateRegistration() }
        return service
    }
}
