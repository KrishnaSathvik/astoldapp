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
        if let baseURL { return RelayTranscriptionService(baseURL: baseURL) }
        return FakeTranscriptionService()
    }
}
