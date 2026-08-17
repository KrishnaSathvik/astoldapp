import Testing
import Foundation
@testable import Yourly

struct TranscriptionServiceTests {
    @Test func fakeReturnsSampleTranscript() async throws {
        let service = FakeTranscriptionService(delay: .milliseconds(1))
        let result = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/x.m4a"), requestID: UUID())
        #expect(result.text == FakeTranscriptionService.sampleText)
        #expect(result.detectedLanguages == ["te", "en"])
    }

    @Test func fakeThrowsConfiguredError() async {
        let service = FakeTranscriptionService(result: .failure(.serviceUnavailable), delay: .milliseconds(1))
        await #expect(throws: TranscriptionError.serviceUnavailable) {
            _ = try await service.transcribe(audioURL: URL(fileURLWithPath: "/tmp/x.m4a"), requestID: UUID())
        }
    }
}
