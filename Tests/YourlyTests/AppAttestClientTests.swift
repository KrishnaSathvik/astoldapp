import Testing
import Foundation
import CryptoKit
@testable import Yourly

/// Path-aware HTTP stub for the two App Attest routes, so the client is tested without a network.
final class AttestStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var registerStatus = 200
    nonisolated(unsafe) static var challengeStatus = 200
    nonisolated(unsafe) static var issuedChallenges: [String] = []
    nonisolated(unsafe) static var registerBodies: [[String: String]] = []
    nonisolated(unsafe) static var transcribeHeaders: [[String: String]] = []
    nonisolated(unsafe) static var transcribeStatus = 200
    /// Statuses to answer successive `/v1/transcriptions` calls with, consumed in order. Empty means
    /// "use `transcribeStatus` every time" — a repair is only observable across two attempts.
    nonisolated(unsafe) static var transcribeStatuses: [Int] = []

    static func reset() {
        registerStatus = 200
        challengeStatus = 200
        issuedChallenges = []
        registerBodies = []
        transcribeHeaders = []
        transcribeStatus = 200
        transcribeStatuses = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let path = request.url?.path ?? ""
        var status = 200
        var body = Data()

        if path.hasSuffix("/v1/app-attest/challenge") {
            status = Self.challengeStatus
            let challenge = "challenge-\(Self.issuedChallenges.count + 1)"
            Self.issuedChallenges.append(challenge)
            body = try! JSONSerialization.data(withJSONObject: [
                "challenge": challenge, "expiresAt": 9_999_999_999,
            ])
        } else if path.hasSuffix("/v1/app-attest/register") {
            status = Self.registerStatus
            // URLProtocol strips httpBody for uploads; the client sets it directly so read either.
            let raw = request.httpBody ?? request.httpBodyStream.map { stream -> Data in
                stream.open()
                defer { stream.close() }
                var data = Data()
                let size = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: size)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                return data
            } ?? Data()
            if let json = try? JSONSerialization.jsonObject(with: raw) as? [String: String] {
                Self.registerBodies.append(json)
            }
            body = try! JSONSerialization.data(withJSONObject: ["installId": "install-1"])
        } else if path.hasSuffix("/v1/transcriptions") {
            Self.transcribeHeaders.append(request.allHTTPHeaderFields ?? [:])
            status = Self.transcribeStatuses.isEmpty
                ? Self.transcribeStatus
                : Self.transcribeStatuses.removeFirst()
            body = try! JSONSerialization.data(withJSONObject: [
                "requestId": "r1", "text": "hello", "languages": ["en"],
            ])
        }

        let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

/// Stands in for DeviceCheck's `DCAppAttestService`, which only works on a real device.
actor FakeAttestKeys: AppAttestKeyProviding {
    nonisolated let isSupported: Bool
    private(set) var generateKeyCalls = 0
    private(set) var attestedHashes: [Data] = []
    private(set) var assertedHashes: [Data] = []
    private let attestFails: Bool

    /// Key ids this fake will refuse to sign for, standing in for a stored id whose Secure Enclave
    /// key did not survive the install.
    private var unsignableKeyIDs: Set<String> = []

    init(isSupported: Bool = true, attestFails: Bool = false) {
        self.isSupported = isSupported
        self.attestFails = attestFails
    }

    func refuseToSign(for keyID: String) { unsignableKeyIDs.insert(keyID) }

    func generateKey() async throws -> String {
        generateKeyCalls += 1
        return "key-\(generateKeyCalls)"
    }

    func attestKey(_ keyID: String, clientDataHash: Data) async throws -> Data {
        if attestFails { throw URLError(.badServerResponse) }
        attestedHashes.append(clientDataHash)
        return Data("attestation-for-\(keyID)".utf8)
    }

    func generateAssertion(_ keyID: String, clientDataHash: Data) async throws -> Data {
        if unsignableKeyIDs.contains(keyID) { throw URLError(.badServerResponse) }
        assertedHashes.append(clientDataHash)
        return Data("assertion-\(assertedHashes.count)".utf8)
    }
}

/// In-memory replacement for the UserDefaults-backed key id storage.
final class MemoryKeyIDStorage: AppAttestKeyIDStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var keyID: String?
    init(keyID: String? = nil) { self.keyID = keyID }
    func loadKeyID() -> String? { lock.withLock { keyID } }
    func saveKeyID(_ newValue: String?) { lock.withLock { keyID = newValue } }
}

func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [AttestStubURLProtocol.self]
    return URLSession(configuration: config)
}

private func makeClient(
    keys: FakeAttestKeys,
    storage: MemoryKeyIDStorage = MemoryKeyIDStorage()
) -> AppAttestClient {
    AppAttestClient(baseURL: URL(string: "https://relay.test")!,
                    session: makeSession(), keys: keys, storage: storage)
}

struct AppAttestClientTests {
    @Test func firstCallRegistersTheKeyAndReturnsAllThreeHeaders() async throws {
        AttestStubURLProtocol.reset()
        let keys = FakeAttestKeys()
        let headers = try await makeClient(keys: keys).headers()

        #expect(headers["x-attest-key-id"] == "key-1")
        #expect(headers["x-attest-challenge"] == AttestStubURLProtocol.issuedChallenges.last)
        let assertion = try #require(headers["x-attest-assertion"].flatMap { Data(base64Encoded: $0) })
        #expect(String(decoding: assertion, as: UTF8.self) == "assertion-1")
        #expect(AttestStubURLProtocol.registerBodies.count == 1)
    }

    @Test func attestationSignsSHA256OfTheIssuedChallenge() async throws {
        AttestStubURLProtocol.reset()
        let keys = FakeAttestKeys()
        _ = try await makeClient(keys: keys).headers()

        let registerChallenge = try #require(AttestStubURLProtocol.registerBodies.first?["challenge"])
        let expected = Data(SHA256.hash(data: Data(registerChallenge.utf8)))
        #expect(await keys.attestedHashes == [expected])
    }

    @Test func assertionSignsSHA256OfTheChallengeSentInTheHeader() async throws {
        AttestStubURLProtocol.reset()
        let keys = FakeAttestKeys()
        let headers = try await makeClient(keys: keys).headers()

        let sent = try #require(headers["x-attest-challenge"])
        let expected = Data(SHA256.hash(data: Data(sent.utf8)))
        #expect(await keys.assertedHashes == [expected])
    }

    @Test func secondCallReusesTheKeyAndDoesNotRegisterAgain() async throws {
        AttestStubURLProtocol.reset()
        let keys = FakeAttestKeys()
        let client = makeClient(keys: keys)
        _ = try await client.headers()
        let second = try await client.headers()

        #expect(await keys.generateKeyCalls == 1)
        #expect(AttestStubURLProtocol.registerBodies.count == 1)
        #expect(second["x-attest-key-id"] == "key-1")
        #expect(await keys.assertedHashes.count == 2)
    }

    @Test func eachRequestCarriesAFreshChallenge() async throws {
        AttestStubURLProtocol.reset()
        let client = makeClient(keys: FakeAttestKeys())
        let first = try await client.headers()
        let second = try await client.headers()

        #expect(first["x-attest-challenge"] != second["x-attest-challenge"])
    }

    @Test func persistedKeyIDSkipsRegistrationOnANewClient() async throws {
        AttestStubURLProtocol.reset()
        let keys = FakeAttestKeys()
        let headers = try await makeClient(keys: keys, storage: MemoryKeyIDStorage(keyID: "stored-key")).headers()

        #expect(headers["x-attest-key-id"] == "stored-key")
        #expect(await keys.generateKeyCalls == 0)
        #expect(AttestStubURLProtocol.registerBodies.isEmpty)
    }

    @Test func unsupportedDeviceReturnsNoHeaders() async throws {
        AttestStubURLProtocol.reset()
        let headers = try await makeClient(keys: FakeAttestKeys(isSupported: false)).headers()

        #expect(headers.isEmpty)
        #expect(AttestStubURLProtocol.issuedChallenges.isEmpty)
    }

    @Test func rejectedRegistrationReturnsNoHeadersAndKeepsNoKey() async throws {
        AttestStubURLProtocol.reset()
        AttestStubURLProtocol.registerStatus = 401
        let storage = MemoryKeyIDStorage()
        let headers = try await makeClient(keys: FakeAttestKeys(), storage: storage).headers()

        #expect(headers.isEmpty)
        #expect(storage.loadKeyID() == nil)
    }

    @Test func failedAttestationReturnsNoHeaders() async throws {
        AttestStubURLProtocol.reset()
        let headers = try await makeClient(keys: FakeAttestKeys(attestFails: true)).headers()

        #expect(headers.isEmpty)
    }
}

struct AppAttestWiringTests {
    @Test func relayServiceSendsAttestHeadersOnTheTranscriptionRequest() async throws {
        AttestStubURLProtocol.reset()
        let service = TranscriptionConfig.makeRelayService(
            baseURL: URL(string: "https://relay.test")!,
            session: makeSession(),
            keys: FakeAttestKeys(),
            storage: MemoryKeyIDStorage())

        let audio = FileManager.default.temporaryDirectory.appendingPathComponent("a-\(UUID()).m4a")
        try Data("audio".utf8).write(to: audio)
        _ = try await service.transcribe(audioURL: audio, requestID: UUID())

        let sent = try #require(AttestStubURLProtocol.transcribeHeaders.first)
        #expect(sent["x-attest-key-id"] == "key-1")
        #expect(sent["x-attest-challenge"] != nil)
        #expect(sent["x-attest-assertion"] != nil)
    }

    @Test func relayServiceStillWorksWhenAttestationIsUnavailable() async throws {
        AttestStubURLProtocol.reset()
        let service = TranscriptionConfig.makeRelayService(
            baseURL: URL(string: "https://relay.test")!,
            session: makeSession(),
            keys: FakeAttestKeys(isSupported: false),
            storage: MemoryKeyIDStorage())

        let audio = FileManager.default.temporaryDirectory.appendingPathComponent("a-\(UUID()).m4a")
        try Data("audio".utf8).write(to: audio)
        let result = try await service.transcribe(audioURL: audio, requestID: UUID())

        #expect(result.text == "hello")
        #expect(AttestStubURLProtocol.transcribeHeaders.first?["x-attest-key-id"] == nil)
    }

    /// **Rewritten 2026-08-31, and the old assertion described the bug.** This required
    /// `storage.loadKeyID() == nil` after a 401 — the lazy design, where a rejected assertion only
    /// *cleared* the key and left re-registration to whatever request happened to come next.
    ///
    /// In production the request that came next was the user's **Retry**. So the repair worked, but
    /// only because somebody was shown "Couldn't transcribe that recording" over a recording that was
    /// entirely fine and tapped a button to fix an authentication problem they should never have seen
    /// (relay logs, 2026-08-31: 401 in 0.43ms, then challenge → register → challenge → 200 with the
    /// same audio). The repair now happens inside the request that was rejected, so what is left
    /// behind is not an empty slot but a live key.
    @Test func aRejectedAssertionReplacesTheStoredKeyWithinTheSameRequest() async throws {
        AttestStubURLProtocol.reset()
        AttestStubURLProtocol.transcribeStatus = 401
        // A key the relay no longer knows — e.g. it restarted and lost its in-memory registry.
        let storage = MemoryKeyIDStorage(keyID: "stale-key")
        let service = TranscriptionConfig.makeRelayService(
            baseURL: URL(string: "https://relay.test")!,
            session: makeSession(),
            keys: FakeAttestKeys(),
            storage: storage)

        let audio = FileManager.default.temporaryDirectory.appendingPathComponent("a-\(UUID()).m4a")
        try Data("audio".utf8).write(to: audio)
        await #expect(throws: TranscriptionError.serviceUnavailable) {
            _ = try await service.transcribe(audioURL: audio, requestID: UUID())
        }

        #expect(storage.loadKeyID() != "stale-key", "the key the relay rejected is gone")
        #expect(storage.loadKeyID() == "key-1", "and a fresh registration took its place")
    }
}

/// A URL stub that fails every request with a chosen transport error, standing in for a relay that
/// is simply not answering.
final class FailingTransportURLProtocol: URLProtocol {
    nonisolated(unsafe) static var code: URLError.Code = .timedOut

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(Self.code))
    }
}

private func makeFailingSession(_ code: URLError.Code) -> URLSession {
    FailingTransportURLProtocol.code = code
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [FailingTransportURLProtocol.self]
    return URLSession(configuration: config)
}

/// An unreachable relay must fail *fast* and say something true, rather than holding the
/// "Transcribing" spinner through two full 60-second URLSession defaults.
struct AttestationTimeoutTests {
    private func client(_ code: URLError.Code) -> AppAttestClient {
        AppAttestClient(baseURL: URL(string: "https://relay.test")!,
                        session: makeFailingSession(code),
                        keys: FakeAttestKeys(),
                        storage: MemoryKeyIDStorage())
    }

    @Test func handshakeCarriesAShortExplicitDeadline() {
        // The upload needs minutes; the two-round-trip handshake in front of it must not.
        #expect(AppAttestClient.handshakeTimeout <= 15)
        #expect(AppAttestClient.handshakeTimeout >= 5)
        #expect(RelayTranscriptionService.uploadTimeout > AppAttestClient.handshakeTimeout)
    }

    @Test func anUnreachableRelayReportsTimedOutRatherThanNoHeaders() async {
        await #expect(throws: TranscriptionError.timedOut) {
            _ = try await client(.timedOut).headers()
        }
    }

    @Test func aRefusedConnectionAlsoReportsTimedOut() async {
        await #expect(throws: TranscriptionError.timedOut) {
            _ = try await client(.cannotConnectToHost).headers()
        }
    }

    @Test func noConnectionReportsOfflineNotTimedOut() async {
        await #expect(throws: TranscriptionError.offline) {
            _ = try await client(.notConnectedToInternet).headers()
        }
    }

    /// A device that cannot attest at all is not a network failure — the relay still decides.
    @Test func unsupportedDeviceStillReturnsNoHeadersWithoutThrowing() async throws {
        let unsupported = AppAttestClient(baseURL: URL(string: "https://relay.test")!,
                                          session: makeFailingSession(.timedOut),
                                          keys: FakeAttestKeys(isSupported: false),
                                          storage: MemoryKeyIDStorage())
        #expect(try await unsupported.headers().isEmpty)
    }

    /// A stored key id whose Secure Enclave key is gone used to yield *no headers at all*, which the
    /// relay answered with 401 and the user read as "Couldn't transcribe that recording" — over a
    /// recording that was perfectly fine. The repair belongs here, before any audio is sent.
    @Test func aStoredKeyThatCanNoLongerSignIsReplacedBeforeTheUpload() async throws {
        AttestStubURLProtocol.reset()
        let keys = FakeAttestKeys()
        let storage = MemoryKeyIDStorage()
        storage.saveKeyID("key-from-a-previous-install")
        await keys.refuseToSign(for: "key-from-a-previous-install")

        let headers = try await makeClient(keys: keys, storage: storage).headers()

        #expect(headers["x-attest-key-id"] == "key-1", "a fresh key was registered")
        #expect(headers["x-attest-assertion"] != nil)
        #expect(headers["x-attest-challenge"] != nil)
        #expect(await keys.generateKeyCalls == 1)
        #expect(storage.loadKeyID() == "key-1", "and the new one is what gets remembered")
    }

    /// The repair happens once. A device that cannot sign for *any* key is not a stale registration,
    /// and must not turn into an endless loop of fresh registrations.
    @Test func theStaleKeyRepairIsAttemptedOnlyOnce() async throws {
        AttestStubURLProtocol.reset()
        let keys = FakeAttestKeys()
        let storage = MemoryKeyIDStorage()
        storage.saveKeyID("old-key")
        await keys.refuseToSign(for: "old-key")
        await keys.refuseToSign(for: "key-1")

        let headers = try await makeClient(keys: keys, storage: storage).headers()

        #expect(headers.isEmpty, "no headers, and the relay decides — exactly as before")
        #expect(await keys.generateKeyCalls == 1, "one repair, not a loop")
    }

    /// The upload must never be attempted once the handshake proved the relay unreachable.
    @Test func theUploadIsSkippedWhenTheHandshakeFails() async {
        AttestStubURLProtocol.reset()
        var service = RelayTranscriptionService(baseURL: URL(string: "https://relay.test")!,
                                                session: makeSession())
        service.attestationHeaders = { _ in throw TranscriptionError.timedOut }

        let audio = FileManager.default.temporaryDirectory
            .appendingPathComponent("attest-timeout-\(UUID().uuidString).m4a")
        try? Data("audio".utf8).write(to: audio)
        defer { try? FileManager.default.removeItem(at: audio) }

        await #expect(throws: TranscriptionError.timedOut) {
            _ = try await service.transcribe(audioURL: audio, requestID: UUID())
        }
        #expect(AttestStubURLProtocol.transcribeHeaders.isEmpty, "no upload should have been made")
    }
}

/// A rejected attestation is not a failed transcription (added 2026-08-31).
///
/// Production evidence: a first Quick Voice upload answered `401` in 0.43ms against a relay that had
/// been up for eleven days. The client then forgot its key, and the user's **Retry** performed the
/// re-registration — so an authentication repair was shown to them as *"Couldn't transcribe that
/// recording"* over audio that transcribed perfectly on the next tap.
struct AttestationRepairOnUploadTests {

    private func audioFile() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("attest-repair-\(UUID().uuidString).m4a")
        try? Data("audio".utf8).write(to: url)
        return url
    }

    @Test func aRejectedAttestationIsRepairedAndTheUploadSucceedsWithoutTheUser() async throws {
        AttestStubURLProtocol.reset()
        AttestStubURLProtocol.transcribeStatuses = [401, 200]

        let repairs = RepairCounter()
        var service = RelayTranscriptionService(baseURL: URL(string: "https://relay.test")!,
                                                session: makeSession())
        service.attestationRejected = { await repairs.record() }

        let audio = audioFile()
        defer { try? FileManager.default.removeItem(at: audio) }

        let result = try await service.transcribe(audioURL: audio, requestID: UUID())

        #expect(result.text.isEmpty == false)
        #expect(await repairs.count == 1, "the registration was repaired exactly once")
        #expect(AttestStubURLProtocol.transcribeHeaders.count == 2, "and the audio was sent again")
    }

    /// Rejected again on a registration made moments ago is the relay refusing this install. One
    /// repair, then the failure stands.
    @Test func aSecondRejectionIsNotRepairedAgain() async throws {
        AttestStubURLProtocol.reset()
        AttestStubURLProtocol.transcribeStatuses = [401, 401]

        let repairs = RepairCounter()
        var service = RelayTranscriptionService(baseURL: URL(string: "https://relay.test")!,
                                                session: makeSession())
        service.attestationRejected = { await repairs.record() }

        let audio = audioFile()
        defer { try? FileManager.default.removeItem(at: audio) }

        await #expect(throws: TranscriptionError.serviceUnavailable) {
            _ = try await service.transcribe(audioURL: audio, requestID: UUID())
        }
        #expect(await repairs.count == 1)
        #expect(AttestStubURLProtocol.transcribeHeaders.count == 2, "two attempts, never a third")
    }

    /// **The rule this must not break** (`RULES.md` §2). A transcription that actually failed — the
    /// relay took the audio, tried, and could not turn it into words — is never retried automatically.
    /// Only 401 gets a second attempt.
    @Test func anOrdinaryTranscriptionFailureIsNeverRetried() async throws {
        AttestStubURLProtocol.reset()
        AttestStubURLProtocol.transcribeStatuses = [502, 200]

        var service = RelayTranscriptionService(baseURL: URL(string: "https://relay.test")!,
                                                session: makeSession())

        let audio = audioFile()
        defer { try? FileManager.default.removeItem(at: audio) }

        await #expect(throws: TranscriptionError.serviceUnavailable) {
            _ = try await service.transcribe(audioURL: audio, requestID: UUID())
        }
        #expect(AttestStubURLProtocol.transcribeHeaders.count == 1,
                "a failed transcription is the user's to retry, and nobody else's")
    }
}

/// Counts repairs across the `@Sendable` boundary the service calls back over.
private actor RepairCounter {
    private(set) var count = 0
    func record() { count += 1 }
}
