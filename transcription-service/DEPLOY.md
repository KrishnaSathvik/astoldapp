# Deploying the relay

> **Live:** `https://as-told-relay.fly.dev` (org `personal`, region `ord`, 1 machine).
> Currently at **stage 1** — `APP_ATTEST_REQUIRED=false`, so the endpoint is unauthenticated.
> Stage 2 is a **release blocker**: a public build must not ship against an open, paid endpoint.

Three stages. Do them in order — each one proves something the next depends on.
Nothing here is done until a **real iPhone** has completed stage 2; the Simulator cannot attest.

## Prerequisites

- A Fly.io account, and `flyctl` authenticated: `fly auth login` (opens a browser).
- Your OpenAI key, already present in `transcription-service/.env`.
- Your Apple **Team ID** (Apple Developer → Membership) for stage 3.

---

## Stage 1 — Deploy without attestation, prove real transcription

```bash
cd transcription-service
fly launch --no-deploy --copy-config --name as-told-relay   # edit fly.toml's app name if taken
fly secrets set OPENAI_API_KEY="$(grep '^OPENAI_API_KEY=' .env | cut -d= -f2-)"
fly deploy
fly status                     # note the hostname, e.g. as-told-relay.fly.dev
curl -s https://as-told-relay.fly.dev/health
```

`fly.toml` already sets `APP_ATTEST_REQUIRED=false` and `RATE_LIMIT_MAX=5`. The endpoint is
**unauthenticated at this stage** — anyone with the URL can spend your OpenAI credit. Keep the URL
private and keep the stage short.

Point the app at it:

```yaml
# project.yml → targets.Yourly.info.properties
# NOT settings.base: Xcode only honors INFOPLIST_KEY_* for keys on its own allowlist and
# silently drops custom ones, which leaves the app on the offline fake transcriber.
info:
  path: App/Info.plist
  properties:
    TranscribeBaseURL: "https://as-told-relay.fly.dev"
```

Verify the key actually shipped (an empty result means the app will use the fake):

```bash
plutil -p build/dd/Build/Products/Debug-iphonesimulator/Yourly.app/Info.plist | grep Transcribe
```

```bash
cd .. && xcodegen generate
```

Build to a real iPhone, record a mixed Telugu/English sentence, confirm the transcript is inserted
at the cursor. Verify no content leaked into the logs:

```bash
fly logs | grep -iE "text|transcript"   # must return nothing
```

## Stage 2 — Turn on App Attest

Release-blocking: a public build must not ship against an unauthenticated transcription endpoint.

Requires stage 1 working, **exactly one machine**, and **a mounted volume**. The attested-key
registry is now durable (`src/security/attestedKeyStore.ts`, SQLite on `/data`) because Apple's
replay defence is an ever-increasing assertion counter — it only rejects a replayed assertion if the
counter it is compared against outlived the process. Challenges remain in-process by design.

Still one machine: challenges are per-process, and so is the rate limiter. A challenge issued by
machine A cannot be consumed by machine B, so roughly half of all requests would 401 and the app
would re-register in a loop that never converges.

```bash
fly volumes create attest_data --size 1 --region ord --app as-told-relay
fly scale count 1 --app as-told-relay   # already applied
fly status --app as-told-relay          # expect a single machine
```

`fly.toml` already declares the `[[mounts]]` and `APP_ATTEST_DB_PATH=/data/app-attest.db`.
`APP_ATTEST_PRODUCTION` must match the entitlement the build is signed with —
`App/Yourly.Debug.entitlements` is `development`, `App/Yourly.Release.entitlements` is `production`.
A mismatch fails with an AAGUID error.

```bash
fly secrets set APP_ATTEST_APP_ID="TEAMID.com.astold.app"     # your real Team ID
fly secrets set APP_ATTEST_REQUIRED=true APP_ATTEST_PRODUCTION=false   # false = Debug build
```

Then **delete the `APP_ATTEST_ALLOW_UNPROTECTED` line from `fly.toml`** and deploy:

```bash
fly deploy
```

That line is the only thing letting a production relay boot with attestation off — `loadConfig`
throws without it. Removing it makes an open endpoint a startup failure rather than a silent risk.

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
