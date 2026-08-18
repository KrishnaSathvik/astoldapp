import Foundation
import CryptoKit

/// Produces the App Attest headers the relay requires for `/v1/transcriptions`
/// (`transcription-service/src/routes/transcribe.ts`).
///
/// Registration (once per install): generate a Secure Enclave key → fetch a challenge → attest the
/// key → `POST /v1/app-attest/register` → remember the key id.
/// Per request: fetch a fresh challenge → sign it → send key id, assertion, and challenge.
///
/// Both the attestation and the assertion sign `SHA256(challenge)`, matching the server's
/// `clientDataHash` (`src/security/attestation.ts`). Any failure yields no headers rather than an
/// error: the relay then answers 401, which the UI already maps to `serviceUnavailable`.
actor AppAttestClient {
    private let baseURL: URL
    private let session: URLSession
    private let keys: AppAttestKeyProviding
    private let storage: AppAttestKeyIDStorage
    /// In-flight registration, so concurrent callers attest exactly once.
    private var registration: Task<String, Error>?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        keys: AppAttestKeyProviding = DeviceCheckAppAttestKeys(),
        storage: AppAttestKeyIDStorage = UserDefaultsAppAttestKeyIDStorage()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.keys = keys
        self.storage = storage
    }

    /// Headers for one transcription request, or empty when attestation is unavailable.
    func headers() async -> [String: String] {
        guard keys.isSupported else { return [:] }
        do {
            let keyID = try await registeredKeyID()
            let challenge = try await fetchChallenge()
            let assertion = try await keys.generateAssertion(
                keyID, clientDataHash: Self.clientDataHash(for: challenge))
            return [
                "x-attest-key-id": keyID,
                "x-attest-assertion": assertion.base64EncodedString(),
                "x-attest-challenge": challenge,
            ]
        } catch {
            return [:]
        }
    }

    /// Forgets the registered key so the next request attests a fresh one. Called when the relay
    /// rejects an assertion — e.g. it restarted and lost its in-memory key registry.
    func invalidateRegistration() {
        storage.saveKeyID(nil)
        registration = nil
    }

    // MARK: - Registration

    private func registeredKeyID() async throws -> String {
        if let stored = storage.loadKeyID() { return stored }
        if let registration { return try await registration.value }

        let task = Task { try await register() }
        registration = task
        defer { registration = nil }
        return try await task.value
    }

    private func register() async throws -> String {
        let keyID = try await keys.generateKey()
        let challenge = try await fetchChallenge()
        let attestation = try await keys.attestKey(
            keyID, clientDataHash: Self.clientDataHash(for: challenge))

        var request = URLRequest(url: baseURL.appending(path: "v1/app-attest/register"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "keyId": keyID,
            "attestationBase64": attestation.base64EncodedString(),
            "challenge": challenge,
        ])
        _ = try await send(request)

        // Only persist a key the relay accepted, so a rejected attempt re-registers next time.
        storage.saveKeyID(keyID)
        return keyID
    }

    // MARK: - Challenges

    private struct ChallengeResponse: Decodable { let challenge: String }

    private func fetchChallenge() async throws -> String {
        var request = URLRequest(url: baseURL.appending(path: "v1/app-attest/challenge"))
        request.httpMethod = "POST"
        let data = try await send(request)
        return try JSONDecoder().decode(ChallengeResponse.self, from: data).challenge
    }

    // MARK: - Transport

    private enum Failure: Error { case rejected }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure.rejected
        }
        return data
    }

    private static func clientDataHash(for challenge: String) -> Data {
        Data(SHA256.hash(data: Data(challenge.utf8)))
    }
}
