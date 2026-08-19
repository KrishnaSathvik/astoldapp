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

    static func reset() {
        registerStatus = 200
        challengeStatus = 200
        issuedChallenges = []
        registerBodies = []
        transcribeHeaders = []
        transcribeStatus = 200
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
            status = Self.transcribeStatus
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

    init(isSupported: Bool = true, attestFails: Bool = false) {
        self.isSupported = isSupported
        self.attestFails = attestFails
    }

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

    @Test func aRejectedAssertionClearsTheStoredKeySoTheNextRequestReRegisters() async throws {
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

        #expect(storage.loadKeyID() == nil)
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
