# Yourly Slice 4 (Phase 9) — Transcription relay backend

> Scaffolds the server-side transcription relay so the iOS client never holds the OpenAI key. Runnable
> and fully testable **without** a key (fake OpenAI client by default). Real `gpt-transcribe` activates
> when `OPENAI_API_KEY` is set. Location: `transcription-service/` (monorepo subdir of Yourly).

**Goal:** A small Node 24 + TypeScript + Fastify service exposing `/health`,
`/v1/app-attest/{challenge,register}`, and `/v1/transcriptions`, that validates + rate-limits + relays
audio to OpenAI and returns `{ requestId, text, languages }` — persisting nothing and logging
metadata only.

**Architecture:** `TranscriptionProvider` interface with `FakeTranscriptionProvider` (default, no
network) and `OpenAITranscriptionProvider` (`gpt-transcribe`). App Attest behind an `AttestationVerifier`
interface (dev bypass + a documented production stub). In-memory rate limiter behind a `RateLimiter`
interface (swap for Redis in prod). Metadata-only logger. Config validated with Zod.

**Tech Stack:** Node 24 LTS, TypeScript, Fastify, @fastify/multipart, Zod, openai SDK, Vitest.

**Non-negotiable (RULES.md §3):** OpenAI key server-side only; never persist audio/transcript/content;
logs carry only request id, route, status, latency, model, byte size, coarse error — never payloads.
Static verbatim prompt; no post-transcription LLM cleanup.

---

## Tasks

1. **Project setup** — `package.json` (type: module, scripts), `tsconfig.json`, `.env.example`,
   `.gitignore`, `config.ts` (Zod env: PORT, NODE_ENV, OPENAI_API_KEY?, MODEL, MAX_AUDIO_BYTES,
   MAX_DURATION_SECONDS, RATE_LIMIT_*, APP_ATTEST_REQUIRED). Install deps.
2. **Prompt + provider contract** — `prompt.ts` (static verbatim instruction), `services/transcription.ts`
   (`TranscriptionProvider`, `TranscriptionResult`), `services/fakeTranscription.ts`,
   `services/openaiTranscription.ts` (gpt-transcribe; language hints; no cleanup pass).
3. **Security** — `security/attestation.ts` (`AttestationVerifier`: `DevBypassVerifier` +
   `AppAttestVerifier` stub with challenge store + documented TODO for full Apple verification),
   `security/rateLimit.ts` (`RateLimiter` interface + `InMemoryRateLimiter`; Redis note).
4. **Observability** — `observability/logger.ts`: metadata-only redacting logger config for Fastify.
5. **Routes + server** — `routes/health.ts`, `routes/appAttest.ts`, `routes/transcribe.ts`
   (multipart audio, size/MIME/duration validation → attestation → rate limit → provider → validate →
   respond; temp buffer discarded after). `server.ts` builds the app; `index.ts` starts it.
6. **Tests (Vitest + fastify.inject)** — health; transcribe success (fake); invalid MIME (415);
   oversized (413); missing/invalid attestation (401) when required; rate limit (429); empty transcript
   (422); response shape; **content-not-logged** assertion.
7. **Dockerfile + README** — multi-stage build; README with run/deploy + iOS client wiring notes.
8. **Wire-up note** — document the `RelayTranscriptionService` seam for the iOS app (Phase 10).

## Out of scope (needs your infra)
Real OpenAI key + a deploy target; full App Attest attestation/assertion crypto against Apple's root;
production Redis; the language-quality benchmark corpus (Phase 11).
