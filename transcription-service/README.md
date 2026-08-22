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
`gpt-4o-transcribe`.

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

Request flow (`src/routes/transcribe.ts`): attestation → rate limit → multipart read → MIME guard →
size guard → **duration guard** → provider → validate → respond. The audio buffer lives only for the
request and is never persisted.

Every guard runs *before* the provider call, because reaching the provider is what costs money.

### Error responses

All errors are `{ requestId, error }`; `audio_duration_exceeded` also carries `maxSeconds`.

| Status | `error` | Meaning |
|---|---|---|
| 400 | `missing_audio` | No file part in the multipart body. |
| 400 | `empty_audio` | The file part was zero bytes. |
| 400 | `unreadable_audio` | No duration could be read from the container — see the duration limit below. |
| 401 | `attestation_failed` | Missing or invalid App Attest assertion. |
| 413 | `audio_too_large` | Over `MAX_AUDIO_BYTES`. |
| 413 | `audio_duration_exceeded` | Over `MAX_DURATION_SECONDS`. |
| 429 | `monthly_voice_limit` | Install is at `MONTHLY_VOICE_SECONDS` for this UTC month. Carries `resetsAt`. Distinct from `rate_limited`. Fallback path — see below. |

A `200` additionally carries `allowanceExhausted: true` and `resetsAt` when *that* request spent
the last of the allowance, so the client can stop the next recording before it starts rather than
have one rejected after it was spoken. A flag and a date only — never a used or remaining figure.
| 415 | `unsupported_media_type` | Content type outside the allowlist. |
| 422 | `no_speech` | The provider returned nothing usable. |
| 429 | `rate_limited` | Over the per-identity rate limit. |
| 502 | `transcription_failed` | The provider errored. |

### The duration limit

Transcription is billed **per minute**, and `MAX_AUDIO_BYTES` cannot bound minutes: 25 MB of 8 kbps
AAC is hours of audio. So `MAX_DURATION_SECONDS` is the cap that actually bounds the cost of a
request, and it is enforced by measuring the uploaded container (`src/media/audioDuration.ts`).

Two properties this relies on:

- **The duration is measured from the bytes**, never taken from a client-supplied field. A caller
  running up the bill would simply lie.
- **The container is identified by magic bytes**, not by `Content-Type`, which is equally
  attacker-controlled. The MIME allowlist governs what is accepted; it never decides how to parse.

Audio whose duration cannot be established is rejected with `unreadable_audio` — **failing open here
would reintroduce the unbounded-minutes hole the check exists to close.** m4a/mp4, WAV, MP3 and raw
ADTS AAC are all measurable; the app itself only ever uploads mono AAC `.m4a`.

The app mirrors the same limit (`VoiceLimits.maxRecordingSeconds`) so a recording stops at 10 minutes
rather than being rejected after the fact. That mirror is a courtesy; **this relay is the authority.**
If you change `MAX_DURATION_SECONDS`, change the client constant to match.

`MONTHLY_VOICE_SECONDS` bounds sustained spend the way `MAX_DURATION_SECONDS` bounds one request and
`RATE_LIMIT_MAX` bounds bursts. The three protect different things and are not interchangeable — do
not raise one because the other two exist (RULES.md §3). Usage lives in the `voice_usage` table on
the `APP_ATTEST_DB_PATH` volume: a hashed install id, a UTC month, and seconds. Reservations are
taken before the paid call and refunded whenever no transcript comes back, so a failed or speechless
request costs the user nothing.

Transcribe headers: `x-request-id` (echoed), and when attestation is required
`x-attest-key-id` / `x-attest-assertion` / `x-attest-challenge`.

## Configuration (`.env`)

| Var | Default | Notes |
|---|---|---|
| `NODE_ENV` | development | `production` **refuses to boot** if attestation is off (see the opt-out below). |
| `PORT` | 8787 | |
| `OPENAI_API_KEY` | _(unset)_ | Unset → fake provider. **Never commit.** |
| `TRANSCRIBE_MODEL` | gpt-4o-transcribe | Chosen by benchmark, never by model recency. |
| `TRANSCRIBE_PROMPT_VARIANT` | punctuated | `punctuated` \| `strictVerbatim` \| `terse` — see `src/prompt.ts`. |
| `MAX_AUDIO_BYTES` | 26214400 | 25 MB → 413 `audio_too_large`. Bounds upload size, **not** billable minutes. |
| `MAX_DURATION_SECONDS` | 300 | 5 min product limit → 413 `audio_duration_exceeded`. Measured from the container; the cap that actually bounds one request. Mirror any change in `VoiceLimits.maxRecordingSeconds`. |
| `MONTHLY_VOICE_SECONDS` | 3600 | Monthly fair-use allowance per attested install → 429 `monthly_voice_limit`. A *soft* ceiling: being under it admits the whole recording. Only successful transcripts count. |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_SECONDS` | 20 / 60 | Per attested-install + IP. |
| `APP_ATTEST_REQUIRED` | false | **Set `true` in production.** |
| `APP_ATTEST_APP_ID` | _(unset)_ | `TEAMID.bundleId`. Required when attestation is on. |
| `APP_ATTEST_PRODUCTION` | false | Must match the build's App Attest entitlement. |
| `APP_ATTEST_DB_PATH` | _(unset)_ | Durable key/counter registry. **Required** when attestation is on; put it on a mounted volume. |
| `APP_ATTEST_ALLOW_UNPROTECTED` | false | Deliberate opt-out for a knowingly-open production relay (staging only). |

## Test

```bash
npm test          # vitest — 84 tests via fastify.inject (no network)
```

Covers: health, success (fake), request-id echo, 415 bad MIME, 413 oversized, 422 empty transcript,
429 rate limit, 401 attestation, the **duration limit** (599/600/601 s boundaries, long low-bitrate
audio that sits far under the byte cap, unreadable audio, and proof the provider is never reached on
a rejection), the container parser against both hand-built fixtures and real ffmpeg output,
rate-limiter + attestation units, the durable attested-key store
(including survival across a restart), the boot-time config rails, and the **metadata-only logger**
(serializers strip body/headers so transcripts/notes can never be logged).

Node prints `ExperimentalWarning: SQLite is an experimental feature` — `node:sqlite` is a built-in
still marked experimental in Node 24. It is expected output, not a failure.

## Deploy

```bash
docker build -t yourly-transcription .
docker run -p 8787:8787 -v attest_data:/data \
  -e NODE_ENV=production -e APP_ATTEST_REQUIRED=true \
  -e APP_ATTEST_APP_ID=TEAMID.com.astold.app \
  -e APP_ATTEST_DB_PATH=/data/app-attest.db \
  -e OPENAI_API_KEY=sk-...   # provide as a runtime secret, never baked into the image
  yourly-transcription
```

The server runs as the unprivileged `node` user. The entrypoint is root only long enough to chown a
freshly mounted volume, then drops privileges with `setpriv` before exec'ing Node.

`/data` must be a real volume: it holds the attested-key registry, and Apple's replay defence is an
assertion counter that has to survive restarts. Provide keys via your platform's secret manager. Use
a Redis-backed rate limiter for multi-instance deploys (see `src/security/rateLimit.ts`).

## App Attest (implemented)

`src/security/appAttestCrypto.ts` implements real verification against Apple's App Attest Root CA
(embedded), using `cbor-x` + `@peculiar/x509`:

- **register**: verify the attestation's cert chain (leaf → intermediate → Apple root), the nonce
  `SHA256(authData ‖ SHA256(challenge))` in the leaf cert's `1.2.840.113635.100.8.2` extension, the
  `rpIdHash == SHA256(appId)`, the AAGUID (`appattestdevelop` in dev / `appattest` in prod), and
  `keyId == credentialId`; then store the public key + signCount.
- **verifyRequest**: consume a one-time challenge, verify the assertion's ECDSA signature over
  `SHA256(authData ‖ SHA256(challenge))` with the stored key, and require a strictly increasing signCount.

Keys and counters live in `src/security/attestedKeyStore.ts`. Enforced deploys use the SQLite-backed
store (Node's built-in `node:sqlite`, no added dependency) on a mounted volume; dev and tests use the
in-memory one. Challenges stay in-process on purpose — they expire in 5 minutes, and losing them to a
restart costs at most one retried request.

Enable it with `APP_ATTEST_REQUIRED=true` + `APP_ATTEST_APP_ID=TEAMID.bundleId`
(+ `APP_ATTEST_PRODUCTION=true` for release builds — this must match the app's
`com.apple.developer.devicecheck.appattest-environment` entitlement: `App/Yourly.Debug.entitlements`
is `development`, `App/Yourly.Release.entitlements` is `production`).

The **iOS client is implemented**: `../Core/Security/AppAttestClient.swift` registers a Secure Enclave
key once per install (challenge → `attestKey` → `/v1/app-attest/register`), then signs a fresh
challenge per transcription and sends `x-attest-key-id` / `x-attest-assertion` / `x-attest-challenge`.
A 401 clears the stored key id so the next request re-registers — the recovery path for a key the
relay no longer recognises (a wiped volume, or a re-signed build). With the durable store, an ordinary
restart or deploy no longer triggers it. The deterministic paths + a real P-256 assertion
round-trip are unit-tested; end-to-end attestation needs a real device (Apple-signed cert chain).

## What still needs completing (your infra)

- **OpenAI key + a deploy target.** The `OpenAITranscriptionProvider` is ready; it just needs the key.
- **Persist attested keys + signCount** — currently in-memory; move to Redis/DB for multi-instance
  and restarts.
- **Redis** for rate limiting across instances.
- **Language-quality benchmark** (Phase 11): a corpus of consented recordings to measure WER, script
  preservation, and unwanted-translation rate before enabling in production.

## Security notes

- All current `npm audit` findings are in the **dev toolchain** (esbuild/vite/vitest dev server) and
  do not ship in the production image (they are devDependencies). Bumping vitest to v4 clears them
  (a breaking test-runner change) and can be done later.

## Wiring the iOS app (done)

`Core/Voice/TranscriptionConfig.swift` picks the backend: set `TranscribeBaseURL` under
`targets.Yourly.info.properties` in `project.yml` (a custom key cannot go through
`INFOPLIST_KEY_*` — Xcode drops it), or the `transcribeBaseURL` UserDefaults key in DEBUG, and the app uses
`RelayTranscriptionService` with App Attest attached; leave it empty and it uses the offline fake.

```
TranscriptionConfig.makeRelayService(baseURL:)
  ├── RelayTranscriptionService   POST /v1/transcriptions (multipart audio)
  └── AppAttestClient             challenge → attest → register, then assertion per request
```

Covered by `Tests/YourlyTests/AppAttestClientTests.swift` (12 tests): registration, key reuse across
requests, `SHA256(challenge)` as the `clientDataHash` for both attestation and assertion, a fresh
challenge per request, headers reaching the transcription request, graceful no-headers on the
Simulator, and re-registration after a 401.
