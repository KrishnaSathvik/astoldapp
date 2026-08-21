# Deploying the relay

> **Verify the live state before any release operation — this document does not record it.** A runtime
> snapshot written here goes stale within days and then misleads the next operator, so the relay's
> current condition is something you measure, never something you read. Before acting, confirm all
> four: `/health` answers, the machine count is **exactly one**, App Attest is **enforced**, and the
> secrets are **deployed rather than staged**. The commands are in *Confirm the machine actually got
> this configuration* below; the unattested probe in *Verify immediately after the deploy* is the one
> that proves enforcement rather than assuming it.
>
> **The relay must run as exactly one machine** for as long as the App Attest challenge store and the
> rate limiter remain process-local. Both live in memory: a second machine multiplies the rate limit by
> the machine count and fails any request whose challenge was issued by the other one. Scaling out
> requires a shared store (Redis) first — see stage 3 and `RULES.md` §8.
>
> **Do not run `fly deploy` to test one component.** `min_machines_running = 1` means any deploy
> recreates the machine. Prepare the whole secured configuration first, then apply it in a **single**
> deploy — batch every pending change (secrets, `[env]`, limits) into that one release.
>
> **`fly scale count 1` is not a bring-up.** It clones the last *release*, not this `fly.toml`, and on
> this app that release predates the hardening — so it silently restores the unprotected endpoint
> while `fly status` looks healthy. This was tried on 19 Aug 2026 and did exactly that; the relay
> served an unattested request before being scaled back to 0. Stage 2 uses `fly deploy`.
>
> Stopping the machine is *not* enough on its own: `auto_start_machines = true` resurrects it on the
> first request (measured: 6.3 s, and the request still reached OpenAI). `fly scale count 0` is what
> actually closes it.

The original staged rollout (open endpoint first, attestation second) is superseded. There is nothing
to be gained by running an unauthenticated paid endpoint at any point, so the secured configuration is
deployed in one step and then verified on a **real iPhone** — the Simulator cannot attest.

## Prerequisites

- A Fly.io account, and `flyctl` authenticated: `fly auth login` (opens a browser).
- Your OpenAI key, already present in `transcription-service/.env`.
- Your Apple **Team ID** (Apple Developer → Membership) — needed in stage 1, before the deploy.

---

## Stage 1 — Prepare the secured configuration (relay stays at 0 machines)

Everything here is done **offline**. No `fly deploy`, no machine.

**Done already (19 Aug 2026):**

- [x] Duration guard committed — `src/media/audioDuration.ts` measures the recording server-side,
      before the paid call, and fails closed on audio it cannot read.
- [x] `fly.toml` hardened — `MAX_DURATION_SECONDS=600`, `MAX_AUDIO_BYTES`, `APP_ATTEST_REQUIRED=true`,
      `APP_ATTEST_DB_PATH=/data/app-attest.db`, and `APP_ATTEST_ALLOW_UNPROTECTED` **deleted**.
      With that line gone, `loadConfig` refuses to boot a production relay that has attestation off,
      so an open paid endpoint is now a startup failure rather than a silent risk. Do not re-add it.
- [x] Durable volume created — `attest_data`, 1 GB, `ord`, encrypted (`vol_vp2xzq27zyz581w4`),
      unattached until the deploy.
- [x] Relay suite green offline — 84 tests, 8 files; `tsc --noEmit` clean.
- [x] The real `fly.toml` `[env]` block validated against `loadConfig`: it boots in the secure shape,
      and is **refused** both with attestation off and with attestation on but no durable registry.

- [x] `APP_ATTEST_APP_ID` staged (19 Aug 2026) — `766WG2GGCA.com.astold.app`. The Team ID is the
      `DEVELOPMENT_TEAM` in `Yourly.xcodeproj/project.pbxproj`, and matches the `TeamIdentifier` in
      the local provisioning profiles; the bundle id is `com.astold.app` (CLAUDE.md).

```bash
# Kept for reference — already done. Secrets, not fly.toml.
fly secrets set APP_ATTEST_APP_ID="766WG2GGCA.com.astold.app" --stage --app as-told-relay
fly secrets list --app as-told-relay    # expect OPENAI_API_KEY + APP_ATTEST_APP_ID
```

`--stage` writes the secret without triggering a deploy, which is the point — the machine stays gone
until the whole configuration is ready. Both secrets read `Staged` until the deploy in stage 2
applies them; that is expected, not a problem to fix.

**Still required before the deploy:** nothing in configuration — stage 2 is ready to run.

`APP_ATTEST_PRODUCTION` must match the entitlement the installed build is signed with:

| Build | Entitlement | `APP_ATTEST_PRODUCTION` | AAGUID |
|---|---|---|---|
| Debug / device-attached | `App/Yourly.Debug.entitlements` | `false` | `appattestdevelop` |
| TestFlight / App Store | `App/Yourly.Release.entitlements` | `true` | `appattest` |

`fly.toml` currently ships `false`, so verification runs against a Debug build first. Flip it before
the TestFlight build, or attestation fails with an AAGUID error.

Point the app at the relay (already done — verify rather than re-do):

```yaml
# project.yml → targets.Yourly.info.properties
# NOT settings.base: Xcode only honors INFOPLIST_KEY_* for keys on its own allowlist and
# silently drops custom ones, which leaves the app on the offline fake transcriber.
info:
  path: App/Info.plist
  properties:
    TranscribeBaseURL: "https://as-told-relay.fly.dev"
```

```bash
# An empty result means the app would silently fall back to FakeTranscriptionService.
plutil -p <built>/Yourly.app/Info.plist | grep Transcribe
```

## Stage 2 — Bring the relay back, once, secured

Everything in stage 1 must be done first. This is the **only** deploy — do not deploy earlier to
test one component, because any deploy recreates the machine (`min_machines_running = 1`).

The attested-key registry is durable (`src/security/attestedKeyStore.ts`, SQLite on `/data`) because
Apple's replay defence is an ever-increasing assertion counter: it only rejects a replayed assertion
if the counter it is compared against outlived the process. Challenges stay in-process by design.

**Exactly one machine.** Challenges are per-process, and so is the rate limiter. A challenge issued
by machine A cannot be consumed by machine B, so roughly half of all requests would 401 and the app
would re-register in a loop that never converges. Do not raise the count without Redis (stage 3).

**Use `fly deploy`, never `fly scale count 1`.** Scaling does not read this `fly.toml`. It clones the
app's current *release* config, so on an app whose last release predates the hardening it silently
recreates the **old image with the old `[env]`** — including `APP_ATTEST_REQUIRED=false` and the
`APP_ATTEST_ALLOW_UNPROTECTED=true` that stops `loadConfig` from refusing it. That reopens the exact
anonymous paid endpoint this document exists to close, and it looks like a successful bring-up:
`fly status` reports a started machine with a passing health check. Staged secrets are not applied
either. Only a deploy publishes a new release carrying this file's `[env]`.

```bash
fly deploy --app as-told-relay          # new image + this fly.toml's [env] + staged secrets, one release
fly status --app as-told-relay          # expect one machine, volume attached
```

If `loadConfig` rejects the environment the machine will fail to start — that is the safety rail
working, not a deploy failure. Read `fly logs` for which invariant it refused.

**Confirm the machine actually got this configuration** before trusting it. `fly.toml` on disk is
what you *intend* to run; these are what you *are* running:

```bash
fly releases --app as-told-relay        # a NEW version, dated now — not the pre-hardening one
fly secrets list --app as-told-relay    # OPENAI_API_KEY + APP_ATTEST_APP_ID, no longer "Staged"
fly logs --app as-told-relay | grep -i "APP_ATTEST_REQUIRED=false"   # must print NOTHING
```

That last line is the one that matters: the relay warns `APP_ATTEST_REQUIRED=false in production —
the endpoint is unprotected` at boot whenever attestation is off. If it appears, the endpoint is
open — `fly scale count 0` immediately, before running any other check.

### Verify immediately after the deploy

Before touching a device, from any shell:

| # | Check | Expected |
|---|---|---|
| 0a | `curl /health` | `200 {"status":"ok"}` |
| 0b | a **well-formed multipart** POST to `/v1/transcriptions` with **no** attest headers | **`401 attestation_failed`** |
| 0c | `fly logs` for that request | **no OpenAI call** — status 401, no `transcription ok`/`failed` |

0b must send a real multipart body. `@fastify/multipart` validates the content type in the
content-type parser, *before* the route handler runs, so a bare `curl -X POST` never reaches the
attestation check at all — it returns `406 FST_INVALID_MULTIPART_CONTENT_TYPE` on an open relay and
a secured one alike. A 406 tells you nothing:

```bash
head -c 2048 /dev/urandom > /tmp/probe.m4a
curl -sS -i -X POST https://as-told-relay.fly.dev/v1/transcriptions \
  -F "file=@/tmp/probe.m4a;type=audio/m4a"
```

Random bytes are deliberate: attestation is step 1 in the handler, before the file is read, so a
secured relay rejects this at 401 without ever looking at the audio. Any other status means the
request got past attestation.

If 0b returns anything other than 401 — 415, 400, 502 — attestation is still off. Scale back to 0
and fix the configuration before going further.

### Verify on a real device

Each step proves something the next depends on. The Simulator cannot attest.

| # | Check | Expected |
|---|---|---|
| 1 | **Fresh install** — delete and reinstall, then record | `challenge` → `register` → 200 transcription in `fly logs` |
| 2 | **Existing install** — record again | `challenge` → 200. **No** `register` |
| 3 | **Restart** — `fly apps restart as-told-relay`, then record | 200, still no `register` (the volume kept the key) |
| 4 | **Invalid assertion** — `curl` the endpoint with a junk `x-attest-assertion` | 401, and no OpenAI call in the logs |
| 5 | **Replayed assertion** — capture one request's three headers and resend them verbatim | 401 (the challenge is one-time; a re-issued one fails the counter check) |
| 6 | **Re-registration recovery** — `fly volumes destroy` the volume, recreate it, record | one 401, then an automatic `register`, then 200 |
| 7 | **Malformed audio, authenticated** — send unreadable bytes with valid attestation | `400 unreadable_audio`, **before** any OpenAI call |
| 8 | **Over-duration, authenticated** — a recording longer than 600 s | `413 audio_duration_exceeded` with `maxSeconds`, **before** any OpenAI call |
| 9 | **Valid transcription from the real app** — record mixed Telugu/English | 200, transcript inserted at the caret, native script preserved |

Step 3 is the one the durable store exists for; step 6 is the client's self-heal path
(`AppAttestClient.invalidateRegistration`). Step 5 is the replay defence Apple's counter provides.

A 401 on register means the attestation chain failed — the message is deliberately generic to
clients, so read `fly logs` for the real reason. This is the first true test of the cert-chain
verification; unit tests only prove protocol shape.

For a TestFlight/Release build, rebuild with the Release entitlement and set
`APP_ATTEST_PRODUCTION=true`.

## Stage 3 — Before real users

- **Redis** for the rate limiter (`src/security/rateLimit.ts`) and the challenge store, which are
  both still per-process. This is what makes more than one machine safe; until then the single
  machine + volume is a deliberate infrastructure constraint, not an oversight.
- **Raise `RATE_LIMIT_MAX`** once real usage is understood.
- **Phase 11 language benchmark** — release-blocking per `RULES.md` §8. It does not block TestFlight:
  ship the current `gpt-4o-transcribe` arm to testers while the corpus is collected, and pick the
  production arm before App Store release.

---

## Rollback

```bash
fly releases                  # list
fly deploy --image <previous-image-ref>
fly apps destroy as-told-relay   # tear down entirely
```

## Transcription model and prompt

`TRANSCRIBE_MODEL` (default `gpt-4o-transcribe`) and `TRANSCRIBE_PROMPT_VARIANT` (default
`punctuated`) are plain non-secret env vars — set them in `fly.toml` under `[env]`, not with
`fly secrets`.

Change them **only** from a benchmark result (`docs/benchmark/README.md`), never because a model is
newer or generically recommended. `compareArms` ranks candidates by content WER → punctuation error
rate → latency among arms that clear the release gate; record `comparison.failing` reasons with the
decision.
