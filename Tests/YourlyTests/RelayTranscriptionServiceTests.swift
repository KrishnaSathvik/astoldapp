import Testing
import Foundation
@testable import Yourly

/// Stubs HTTP responses so the relay client is tested without a network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var failWith: URLError.Code?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        if let code = Self.failWith {
            client?.urlProtocol(self, didFailWithError: URLError(code))
            return
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status,
                                       httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

private func makeService() -> RelayTranscriptionService {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return RelayTranscriptionService(baseURL: URL(string: "https://relay.test")!,
                                     session: URLSession(configuration: config))
}

private func tempAudio() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID()).m4a")
    try Data("audio".utf8).write(to: url)
    return url
}

struct RelayTranscriptionServiceTests {
    @Test func decodesSuccess() async throws {
        StubURLProtocol.failWith = nil
        StubURLProtocol.status = 200
        StubURLProtocol.body = try JSONSerialization.data(withJSONObject: [
            "requestId": "r1", "text": "నాకు idea వచ్చింది", "languages": ["te", "en"],
        ])
        let result = try await makeService().transcribe(audioURL: try tempAudio(), requestID: UUID())
        #expect(result.text == "నాకు idea వచ్చింది")
        #expect(result.detectedLanguages == ["te", "en"])
    }

    @Test func maps429ToRateLimited() async throws {
        StubURLProtocol.failWith = nil
        StubURLProtocol.status = 429
        StubURLProtocol.body = Data("{}".utf8)
        await #expect(throws: TranscriptionError.rateLimited) {
            _ = try await makeService().transcribe(audioURL: try tempAudio(), requestID: UUID())
        }
    }

    @Test func maps413ToTooLarge() async throws {
        StubURLProtocol.failWith = nil
        StubURLProtocol.status = 413
        StubURLProtocol.body = Data("{}".utf8)
        await #expect(throws: TranscriptionError.requestTooLarge) {
            _ = try await makeService().transcribe(audioURL: try tempAudio(), requestID: UUID())
        }
    }

    @Test func maps422ToNoSpeech() async throws {
        StubURLProtocol.failWith = nil
        StubURLProtocol.status = 422
        StubURLProtocol.body = Data("{}".utf8)
        await #expect(throws: TranscriptionError.noSpeech) {
            _ = try await makeService().transcribe(audioURL: try tempAudio(), requestID: UUID())
        }
    }

    @Test func offlineMapsToOffline() async throws {
        StubURLProtocol.status = 200
        StubURLProtocol.failWith = .notConnectedToInternet
        await #expect(throws: TranscriptionError.offline) {
            _ = try await makeService().transcribe(audioURL: try tempAudio(), requestID: UUID())
        }
        StubURLProtocol.failWith = nil
    }

    @Test func emptyTextIsInvalid() async throws {
        StubURLProtocol.failWith = nil
        StubURLProtocol.status = 200
        StubURLProtocol.body = try JSONSerialization.data(withJSONObject: ["requestId": "r", "text": ""])
        await #expect(throws: TranscriptionError.invalidResponse) {
            _ = try await makeService().transcribe(audioURL: try tempAudio(), requestID: UUID())
        }
    }
}
