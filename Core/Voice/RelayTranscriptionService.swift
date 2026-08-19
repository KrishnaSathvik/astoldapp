import Foundation

/// Real transcription: uploads the recording to the server-side relay (which holds the OpenAI key)
/// and maps the response to a TranscriptionResult. See transcription-service/ and docs/05-architecture.md §14.
///
/// The relay endpoint returns `{ requestId, text, languages }`. HTTP status codes map to domain errors
/// so the UI can show concise copy (RULES.md §5). Nothing about the note is sent — only the audio.
struct RelayTranscriptionService: TranscriptionService {
    let baseURL: URL
    var session: URLSession = .shared
    /// Optional App Attest headers provider (production). Returns header fields to attach per request.
    var attestationHeaders: @Sendable (_ requestID: UUID) async -> [String: String] = { _ in [:] }
    /// Called when the relay rejects the attestation, so the client can re-register before retrying.
    var attestationRejected: @Sendable () async -> Void = {}

    private struct Response: Decodable {
        let requestId: String?
        let text: String?
        let languages: [String]?
        let error: String?
        /// Present on `audio_duration_exceeded` — the relay's configured limit, in seconds.
        let maxSeconds: Int?
    }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        let data: Data
        do {
            data = try Data(contentsOf: audioURL)
        } catch {
            throw TranscriptionError.invalidResponse
        }

        let boundary = "yourly-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "v1/transcriptions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(requestID.uuidString, forHTTPHeaderField: "x-request-id")
        for (k, v) in await attestationHeaders(requestID) { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = Self.multipartBody(audio: data, filename: audioURL.lastPathComponent, boundary: boundary)

        let responseData: Data
        let httpResponse: HTTPURLResponse
        do {
            let (d, r) = try await session.data(for: request)
            responseData = d
            guard let http = r as? HTTPURLResponse else { throw TranscriptionError.invalidResponse }
            httpResponse = http
        } catch let error as URLError where error.code == .notConnectedToInternet || error.code == .networkConnectionLost {
            throw TranscriptionError.offline
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.serviceUnavailable
        }

        switch httpResponse.statusCode {
        case 200:
            guard let decoded = try? JSONDecoder().decode(Response.self, from: responseData),
                  let text = decoded.text, !text.isEmpty else {
                throw TranscriptionError.invalidResponse
            }
            return TranscriptionResult(text: text, detectedLanguages: decoded.languages ?? [])
        case 401:
            await attestationRejected()                   // stale registration — re-attest next time
            throw TranscriptionError.serviceUnavailable   // attestation failed — not user-facing detail
        case 400:
            // The relay could not read a duration out of the file, so it refused to pay to
            // transcribe it. Nothing the user can act on beyond trying again.
            throw TranscriptionError.invalidResponse
        case 413:
            // Two different limits share this status; the error code separates them so the user is
            // told which one they hit ("too long" and "too large" are not the same problem).
            let decoded = try? JSONDecoder().decode(Response.self, from: responseData)
            guard decoded?.error == "audio_duration_exceeded" else {
                throw TranscriptionError.requestTooLarge
            }
            throw TranscriptionError.recordingTooLong(
                maxSeconds: decoded?.maxSeconds ?? VoiceLimits.maxRecordingSeconds
            )
        case 415:
            throw TranscriptionError.invalidResponse
        case 422:
            throw TranscriptionError.noSpeech
        case 429:
            throw TranscriptionError.rateLimited
        default:
            throw TranscriptionError.serviceUnavailable
        }
    }

    static func multipartBody(audio: Data, filename: String, boundary: String) -> Data {
        var body = Data()
        func append(_ s: String) { body.append(s.data(using: .utf8)!) }
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audio)
        append("\r\n--\(boundary)--\r\n")
        return body
    }
}
