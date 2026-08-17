# Yourly Transcription Service

A small **server-side relay** that transcribes recordings via OpenAI so the iOS app never holds the
API key. Build-plan Phase 9 (`../docs/07-build-plan.md`); contract in
`../docs/04-voice-transcription.md` and `../RULES.md` §3.

> The backend exists **only** because paid transcription credentials cannot safely live in the client —
> not because the product needs a cloud backend. It persists nothing and logs metadata only.

## Why it exists

- The OpenAI API key stays **server-side** — never in the app binary (RULES.md §3, non-negotiable).
- Anti-abuse via **App Attest** + **rate limiting** (there is no user account).
- **Verbatim** transcription only — no translate/summarize/rewrite, no post-transcription cleanup.

## Requirements

Node.js **24 LTS**. Install: `npm install`.

## Run

```bash
cp .env.example .env
npm run dev          # tsx watch, hot reload
# or
npm run build && npm start
```

With **no `OPENAI_API_KEY`**, it uses a built-in **fake** provider (deterministic Telugu+English
sample, no network) — ideal for local dev, CI, and wiring the app. Set the key to relay to real
`gpt-transcribe`.

```bash
curl -s localhost:8787/health
curl -s -X POST localhost:8787/v1/transcriptions -F "audio=@note.m4a;type=audio/m4a"
```

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness. |
| POST | `/v1/app-attest/challenge` | Issue a one-time attestation challenge. |
| POST | `/v1/app-attest/register` | Register an attested App Attest key. |
| POST | `/v1/transcriptions` | multipart `audio` file → `{ requestId, text, languages }`. |

Request flow (`src/routes/transcribe.ts`): attestation → rate limit → multipart read → MIME/size
guard → provider → validate → respond. The audio buffer lives only for the request and is never
persisted.

Transcribe headers: `x-request-id` (echoed), and when attestation is required
`x-attest-key-id` / `x-attest-assertion` / `x-attest-challenge`.

## Configuration (`.env`)

| Var | Default | Notes |
|---|---|---|
| `NODE_ENV` | development | `production` warns if attestation is off. |
| `PORT` | 8787 | |
| `OPENAI_API_KEY` | _(unset)_ | Unset → fake provider. **Never commit.** |
| `TRANSCRIBE_MODEL` | gpt-transcribe | |
| `MAX_AUDIO_BYTES` | 26214400 | 25 MB → 413 when exceeded. |
| `MAX_DURATION_SECONDS` | 600 | 10 min product limit. |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SECONDS` | 20 / 60 | Per attested-install + IP. |
| `APP_ATTEST_REQUIRED` | false | **Set `true` in production.** |

## Test

```bash
npm test          # vitest — 17 tests via fastify.inject (no network)
```

Covers: health, success (fake), request-id echo, 415 bad MIME, 413 oversized, 422 empty transcript,
429 rate limit, 401 attestation, rate-limiter + attestation units, and the **metadata-only logger**
(serializers strip body/headers so transcripts/notes can never be logged).

## Deploy

```bash
docker build -t yourly-transcription .
docker run -p 8787:8787 \
  -e NODE_ENV=production -e APP_ATTEST_REQUIRED=true \
  -e OPENAI_API_KEY=sk-...   # provide as a runtime secret, never baked into the image
  yourly-transcription
```

Runs as non-root. Provide the key and secrets via your platform's secret manager. Use a Redis-backed
rate limiter for multi-instance deploys (see `src/security/rateLimit.ts`).

## What still needs completing (your infra)

- **OpenAI key + a deploy target.** The `OpenAITranscriptionProvider` is ready; it just needs the key.
- **Full App Attest crypto.** `AppAttestVerifier` (`src/security/attestation.ts`) has the structure
  (challenge store, register/verify seams) with the Apple attestation/assertion verification left as a
  documented TODO. Until completed, run with `APP_ATTEST_REQUIRED=false` **only** outside production.
- **Redis** for rate limiting across instances.
- **Language-quality benchmark** (Phase 11): a corpus of consented recordings to measure WER, script
  preservation, and unwanted-translation rate before enabling in production.

## Security notes

- All current `npm audit` findings are in the **dev toolchain** (esbuild/vite/vitest dev server) and
  do not ship in the production image (they are devDependencies). Bumping vitest to v4 clears them
  (a breaking test-runner change) and can be done later.

## Wiring the iOS app (Phase 10)

The app already has the seam: `TranscriptionService` in
`../Yourly` (`Core/Voice/TranscriptionService.swift`), currently backed by `FakeTranscriptionService`.
Phase 10 adds a `RelayTranscriptionService` that POSTs the recording to `/v1/transcriptions` and maps
the JSON to `TranscriptionResult`, e.g.:

```swift
struct RelayTranscriptionService: TranscriptionService {
    let baseURL: URL
    func transcribe(audioURL: URL, requestID: UUID) async throws -> TranscriptionResult {
        var req = URLRequest(url: baseURL.appending(path: "v1/transcriptions"))
        req.httpMethod = "POST"
        req.setValue(requestID.uuidString, forHTTPHeaderField: "x-request-id")
        // multipart body with the audio file (+ App Attest headers in production)
        // decode { requestId, text, languages } → TranscriptionResult
        ...
    }
}
```

Swap `FakeTranscriptionService()` for `RelayTranscriptionService(baseURL:)` in
`Features/Editor/EditorView.startVoice` — everything downstream (insertion, autosave, error/retry) is
already in place.
