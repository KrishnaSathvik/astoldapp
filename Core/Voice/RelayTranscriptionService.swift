import Foundation

/// Real transcription: uploads the recording to the server-side relay (which holds the OpenAI key)
/// and maps the response to a TranscriptionResult. See transcription-service/ and docs/05-architecture.md §14.
///
/// The relay endpoint returns `{ requestId, text, languages }`. HTTP status codes map to domain errors
/// so the UI can show concise copy (RULES.md §5). Nothing about the note is sent — only the audio.
struct RelayTranscriptionService: TranscriptionService {
    /// The whole point of the relay: the recording is uploaded. Stated explicitly rather than
    /// inherited from the protocol default, because this is what turns on the one-time disclosure
    /// (`TranscriptionConsent`).
    var sendsAudioOffDevice: Bool { true }

    let baseURL: URL
    var session: URLSession = .shared
    /// Optional App Attest headers provider (production). Returns header fields to attach per
    /// request, and throws a `TranscriptionError` when the relay could not be reached at all — the
    /// upload is then skipped rather than spending a second timeout to learn the same thing.
    var attestationHeaders: @Sendable (_ requestID: UUID) async throws -> [String: String] = { _ in [:] }
    /// Called when the relay rejects the attestation, so the client can re-register before retrying.
    var attestationRejected: @Sendable () async -> Void = {}

    private struct Response: Decodable {
        let requestId: String?
        let text: String?
        let languages: [String]?
        let error: String?
        /// Present on `audio_duration_exceeded` — the relay's configured limit, in seconds.
        let maxSeconds: Int?
        /// Present on `monthly_voice_limit`, and on the success that spends the last of the
        /// allowance — ISO-8601 start of the next UTC month.
        let resetsAt: String?
        /// Present only on the successful response that exhausted the monthly allowance.
        let allowanceExhausted: Bool?
    }

    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        let data: Data
        do {
            data = try Data(contentsOf: audioURL)
        } catch {
            throw TranscriptionError.invalidResponse
        }

        var (responseData, httpResponse) = try await upload(data, filename: audioURL.lastPathComponent,
                                                            requestID: requestID)

        // **A rejected attestation is not a failed transcription** (added 2026-08-31).
        //
        // The relay rejects before it reads a byte of audio, and the rejection means our registration
        // is stale — the relay restarted and forgot the key, or the install changed underneath it.
        // Repairing that and sending once more is *completing the request the user asked for*, and it
        // is deliberately the only status that gets a second attempt.
        //
        // This is not the automatic retry `RULES.md` §2 forbids. That rule is about a transcription
        // that failed: audio the relay took, tried, and could not turn into words — which stays
        // explicit, user-initiated, and untouched below. Here nothing was ever attempted. Without
        // this, the first recording after a stale registration told the user "Couldn't transcribe
        // that recording" about a recording that was entirely fine, and made them tap **Retry** to
        // perform an authentication repair they should never have been shown.
        if httpResponse.statusCode == 401 {
            await attestationRejected()                   // forget the key; the next call re-attests
            (responseData, httpResponse) = try await upload(data, filename: audioURL.lastPathComponent,
                                                           requestID: requestID)
        }

        switch httpResponse.statusCode {
        case 200:
            guard let decoded = try? JSONDecoder().decode(Response.self, from: responseData),
                  let text = decoded.text, !text.isEmpty else {
                throw TranscriptionError.invalidResponse
            }
            // The relay reports exhaustion on the very request that caused it, so the app can stop
            // the *next* recording rather than let it be spoken and then refused.
            return TranscriptionResult(
                text: text,
                detectedLanguages: decoded.languages ?? [],
                allowanceExhaustedUntil: decoded.allowanceExhausted == true
                    ? decoded.resetsAt.flatMap(Self.isoDate)
                    : nil
            )
        case 401:
            // Rejected again, with a registration made moments ago. That is the relay refusing this
            // install rather than a stale key, and there is nothing here the user can act on.
            throw TranscriptionError.serviceUnavailable
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
            // Two unrelated limits share this status, so the code decides which. Sending too fast
            // clears in a moment; the monthly allowance clears in days, and telling someone to
            // "try again shortly" would simply be false.
            let decoded = try? JSONDecoder().decode(Response.self, from: responseData)
            guard decoded?.error == "monthly_voice_limit" else {
                throw TranscriptionError.rateLimited
            }
            throw TranscriptionError.monthlyLimitReached(
                resetsAt: decoded?.resetsAt.flatMap(Self.isoDate)
            )
        default:
            throw TranscriptionError.serviceUnavailable
        }
    }

    /// One attempt: fresh attestation headers, then the multipart upload.
    ///
    /// Separated out so a rejected attestation can be repaired and the upload made once more without
    /// the audio being read from disk twice, and without any other failure gaining a second attempt.
    private func upload(_ audio: Data,
                        filename: String,
                        requestID: UUID) async throws -> (Data, HTTPURLResponse) {
        // The handshake is deliberately *not* on the upload's clock: it is two tiny round trips with
        // a short deadline (`AppAttestClient.handshakeTimeout`), while the upload below carries
        // minutes of audio and waits on the transcription itself.
        let headers = try await attestationHeaders(requestID)

        let boundary = "yourly-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appending(path: "v1/transcriptions"))
        request.httpMethod = "POST"
        // Idle-time budget for uploading the recording and waiting on the transcription. Long on
        // purpose: the relay accepts up to `VoiceLimits.maxRecordingSeconds` of audio, and a long
        // recording legitimately takes far more than a handshake's worth of time to come back.
        // Confirm the real ceiling against the live relay on device before release.
        request.timeoutInterval = Self.uploadTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(requestID.uuidString, forHTTPHeaderField: "x-request-id")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        request.httpBody = Self.multipartBody(audio: audio, filename: filename, boundary: boundary)

        do {
            let (d, r) = try await session.data(for: request)
            guard let http = r as? HTTPURLResponse else { throw TranscriptionError.invalidResponse }
            return (d, http)
        } catch let error as URLError {
            throw TranscriptionError.transport(error)
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.serviceUnavailable
        }
    }

    /// The relay sends `resetsAt` with fractional seconds; accept it with or without them rather
    /// than letting a formatter mismatch turn a known reset date into an unknown one.
    static func isoDate(_ raw: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }

    /// Idle timeout for the upload + transcription round trip. Not the handshake's short deadline.
    static let uploadTimeout: TimeInterval = 180

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
