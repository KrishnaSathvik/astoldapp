# Voice Transcription Specification

## 1. Product role

Voice is not a separate note type.

It is an **input method inside the plain-text editor**.

After transcription, the resulting words become ordinary editable note text. V1 does not preserve a permanent "voice block" or recording object after successful transcription.

---

## 2. Verbatim Capture Contract

This is a core product contract.

> ### Preserve the words. Format the speech.
>
> _(Refined 2026-08-18. The forbidden list is unchanged; what changed is that punctuation was never
> supposed to be on it — writing speech down includes writing down its sentence boundaries.)_

**Allowed — readability formatting:**

- capitalization
- sentence boundaries and full stops
- commas, question marks, exclamation marks where clearly supported by the speech
- punctuation inferred naturally from delivery
- paragraph breaks at meaningful pauses or topic changes, where reliably detected
- minimal whitespace around the inserted transcript

**Forbidden — the transcription path must not intentionally:**

- translate speech
- summarize speech
- rewrite or paraphrase speech
- polish grammar
- replace vocabulary with different words
- change tone
- make sentences "more professional"
- remove slang because it sounds informal
- convert Telugu/Hindi to English by default
- replace the user's content with an AI-generated interpretation

The boundary, in one example:

| | |
|---|---|
| **Spoken** | `Actually I don't know maybe we can go Saturday but if Ravi is coming then Sunday is probably better what do you think` |
| **Allowed** | `Actually, I don't know. Maybe we can go Saturday, but if Ravi is coming, then Sunday is probably better. What do you think?` |
| **Forbidden** | `Ravi and I should probably go on Sunday instead of Saturday.` |

The first keeps every word the speaker said and only adds the marks that written language uses to
represent speech. The second is a different sentence.

The goal is:

> **Spoken thought → faithful text representation of that spoken thought.**

Speech recognition can make mistakes. The product must never claim perfect transcription.

---

## 3. V1 language targets

### Required benchmark groups

1. English
2. Indian English
3. Telugu
4. Hindi
5. Telugu + English code-switching
6. Hindi + English code-switching

### Writing-system goal

If Telugu is spoken, prefer Telugu script.

If Hindi is spoken, prefer Devanagari.

If English terms occur naturally inside Telugu/Hindi speech, preserve the mixed-language character where the transcription model can reliably do so.

Example goal:

```text
నాకు Alaska trip గురించి ఒక idea వచ్చింది.
```

not automatic English translation.

---

## 4. Technical transcription choice

### V1 recommended path

**Record completed audio → send file → `gpt-4o-transcribe` → insert final transcript.**

> Production currently uses `gpt-4o-transcribe`. `gpt-transcribe` is a benchmark candidate and must not replace production until the multilingual quality gate passes (`docs/benchmark/README.md`, RULES.md §8).

Reason:

- product does not require live words while user is still speaking
- completed-file transcription is simpler to reason about
- OpenAI's file-transcription models are built for recorded speech in its original language
- API supports language/context guidance
- no need to introduce Realtime/WebRTC complexity for V1

### Future option

If product later needs live transcript deltas while speaking, evaluate Realtime transcription with `gpt-live-transcribe`.

Do not build Realtime merely because it exists.

---

## 5. API security boundary

Never put the OpenAI standard API key in:

- Info.plist
- app source
- remote config readable by clients
- Keychain as a bundled secret
- obfuscated application binary

Use a developer-controlled server.

### Flow

```text
iPhone
  |
  | HTTPS + attested request
  v
Transcription Relay
  |
  | server-side OpenAI credential
  v
OpenAI Transcriptions API
  |
  | transcript
  v
Relay
  |
  | transcript only
  v
iPhone
```

---

## 6. Audio lifecycle

### Start recording

- configure audio session
- create temporary protected audio file
- show recording UI
- capture elapsed time/audio level

### Cancel

- stop recorder
- delete temporary file
- no text mutation

Cancel is the **only** way a recording is deliberately thrown away, and it is always an explicit tap.
Leaving the note is not cancelling — see "Leaving mid-recording" below.

### Done

- stop recorder
- close/finalize file
- validate non-empty recording
- **one-time disclosure gate** — see below; on a consented install this is a no-op
- show `Transcribing…`
- upload

### Leaving mid-recording — **Back finishes, it does not cancel** (fixed 2026-08-19)

Navigating away while a recording is running behaves exactly as **Done** does: stop the recorder,
finalize the file, upload, insert the transcript into the note.

This was a data-loss bug. Leaving previously called `cancel()`, which deleted the audio before it
was ever transcribed — so tapping Back mid-sentence silently destroyed everything the user had said,
and the note went with it for being empty. Every *other* way a recording ends already finished the
capture:

| Exit | Behavior |
|---|---|
| Done | finish + transcribe |
| Backgrounding the app | finish + transcribe |
| Call / Siri interruption | finish + transcribe |
| 10-minute duration cap | finish + transcribe |
| **Back** | **was: delete. now: finish + transcribe** |

The rule the rest of the capture already followed: *the words are already said, and dropping them is
the one outcome worse than a rejected upload.* Back was the single exit that broke it.

`VoiceCaptureModel.finishOnLeave()` owns this. The microphone is stopped either way, so nothing is
left hot and no temporary audio survives. The one exception is a first recording whose disclosure has
not been accepted — that audio cannot be sent and cannot be kept, so leaving still discards it.

### One-time transcription disclosure

The microphone permission covers *recording*. It does not cover *sending*. App Review Guideline
5.1.2(i) requires clearly disclosing where personal data is shared with third parties — "including
with third-party AI" — and obtaining explicit permission before doing so. Apps with an account
collect this at sign-up; As Told deliberately has none (RULES.md §1), so the only honest place for it
is the moment before the first upload.

- Asked **after Done, before the first upload** — never before recording, which would collide with
  the microphone prompt and put a legal question in front of someone who has not tried voice yet.
- Asked **once per install**, persisted locally (`voiceTranscriptionConsent`). Nothing about the
  decision is transmitted.
- The recording is already captured and **stays on disk unread while the question is open**. Nothing
  is uploaded until it is answered.
- **Continue** → remember, then send the waiting recording.
- **Cancel** → delete the recording, send nothing, leave the note untouched. Declining is not
  remembered as consent, so the question returns on the next attempt.
- Abandoning it (leaving the note mid-question) aborts the capture and deletes the audio. This is the
  one place leaving still discards: the audio may not be sent without an answer, and it may not sit
  on disk with no UI left to ask (RULES.md §3).
- Only applies when the configured service actually uploads (`TranscriptionService.sendsAudioOffDevice`).
  Disclosing a transfer that does not happen would be its own inaccuracy, so the local fake is never
  gated. The property defaults to `true`, so a new service that forgets to answer discloses rather
  than silently skipping.

Copy is deliberately short — name the recipient, say what is *not* sent, two choices. The detail
belongs in the privacy policy, not in a sheet interrupting someone mid-thought.

### Success

- receive transcript
- normalize only transport artifacts, not language/grammar
- insert at intended cursor anchor
- autosave
- delete temporary audio immediately

### Failure

Keep temporary file only for explicit retry.

Do not silently queue it for future upload without the user's knowledge.

### Discard

Delete temporary file.

---

## 7. Recording format

Recommended starting point:

- `.m4a`
- mono
- AAC
- speech-appropriate bitrate/sample settings

Exact audio settings should be benchmarked for:

- transcription quality
- upload speed
- file size
- quiet speech
- noisy speech

Do not prematurely downsample so aggressively that recognition quality suffers.

### Product limit

The maximum voice capture duration is **10 minutes**, and it protects:

- latency
- memory/storage
- service cost
- accidental long recordings

**The relay is the authority.** It measures the duration of the uploaded audio from the container
itself and rejects anything longer with `413 audio_duration_exceeded`, before the paid call is made
(`transcription-service/src/media/audioDuration.ts`, `MAX_DURATION_SECONDS`). A client-reported
duration is never trusted, and the byte cap is not a substitute: transcription is billed per minute,
and 25 MB of low-bitrate audio is hours of speech. Audio whose duration cannot be read is rejected
(`400 unreadable_audio`) rather than sent — failing open would reopen the hole the check closes.

The app mirrors the same limit in `VoiceLimits.maxRecordingSeconds` so a recording **stops** at the
cap instead of being rejected after the fact. Stopping at the limit is the ordinary finish path: the
audio captured so far is kept and transcribed, never discarded. Keep the two constants in step.

Do not hardcode business limits deep in the view layer.

---

## 8. Cursor insertion contract

### Before recording

Capture the user's intended insertion selection/location.

Two cases, decided at the moment the mic is tapped and owned by that recording:

| State when recording starts | Where the transcript lands |
|---|---|
| Caret in the body (the user was editing) | at the captured caret |
| No caret — existing note open for reading, keyboard hidden | appended to the end of the note |

Voice never creates a separate object; it is another way of writing into the same note.

### During recording

The note remains visible.

To guarantee deterministic insertion in V1, body editing may be temporarily disabled while the recording/transcription operation owns the insertion anchor.

### On success

Insert transcript:

- at selection
- replacing selected text only if that behavior is explicitly intended
- otherwise at cursor
- preserving surrounding content

### Whitespace

The app may insert minimal boundary whitespace/newlines required to avoid joining words accidentally.

It must not otherwise rewrite transcript content.

---

## 9. Transcription instructions

Use the provider's transcription-specific prompting/context capabilities rather than a second text-generation pass.

Shipping static instruction (`transcription-service/src/prompt.ts`, variant `punctuated`):

```text
Transcribe the recording faithfully in the original language(s).
Preserve English, Telugu, and Hindi code-switching exactly as spoken.
Preserve the speaker's actual words, slang, repetitions, and names.
Add natural capitalization, punctuation, sentence boundaries, and paragraph breaks where the
speech supports them.
Do not translate, summarize, rewrite, paraphrase, or correct grammar.
Prefer the native writing system for Telugu and Hindi when spoken.
```

The exact prompt must be tested empirically — it is not assumed optimal. `PROMPT_VARIANTS` holds the
benchmark arms (`punctuated`, `strictVerbatim` as the pre-2026-08-18 control, `terse`), selected at
runtime with `TRANSCRIBE_PROMPT_VARIANT` and compared with `compareArms` (§16).

### Critical privacy rule

Do not send the complete existing note as prompt context in V1.

That would expand server exposure beyond the audio the user explicitly chose to transcribe.

---

## 10. Language hints

The current transcription API supports expected language hints for supported language codes.

Integration should evaluate expected hints for:

- English
- Telugu
- Hindi

Do not force a single language for every recording because code-switching is a core use case.

If explicit multi-language hints reduce quality for a test group, fall back to model language detection for that group.

This decision is benchmark-driven, not assumption-driven.

---

## 11. No post-transcription LLM cleanup

Do **not** run transcript through a general language model with prompts such as:

- "fix mistakes"
- "clean grammar"
- "make this readable"
- "correct punctuation and wording"

That breaks the product contract.

Allowed deterministic cleanup is limited to transport/UI artifacts, for example:

- trimming an accidental trailing transport newline
- preventing double spaces created by insertion boundaries

Punctuation is allowed (§2) but **must come from the transcription model itself**. A second
generative pass that adds punctuation is still a rewrite pass and is forbidden — the failure mode is
that it also quietly "improves" wording.

---

## 12. Error states

### Microphone denied

Message:

`Microphone access is off.`

Action:

`Open Settings`

Do not repeatedly show the system permission request once denied.

### No connection

Message:

`A connection is needed to transcribe this recording.`

Actions:

- Retry
- Discard

### Timeout/service failure

Message:

`Couldn't transcribe that recording.`

Actions:

- Retry
- Discard

### Empty/no speech

Message:

`No speech was detected.`

Actions:

- Try Again
- Discard

### Invalid server output

Treat as failure.

Never insert guessed text.

---

## 13. Privacy requirements

Backend must not intentionally persist:

- raw audio
- transcript
- note title
- note body
- search terms

Production logs may contain metadata such as:

- request ID
- status code
- latency
- audio byte size
- approximate duration
- model identifier
- error category

Do not log content payloads.

---

## 14. Abuse protection

There is no user account, but the transcription endpoint has real cost.

Production controls:

- App Attest validation
- per-attested-install/device rate limiting
- IP-level anomaly limits as secondary defense
- request size limit
- duration limit
- MIME validation
- timeout
- server-side model allowlist

Do not treat an anonymous public endpoint as sufficient.

---

## 15. Quality benchmark

Build a versioned test corpus before release.

### Recommended minimum

At least 20 recordings per important group for early QA, growing over time.

### Dimensions

| Dimension | Examples |
|---|---|
| English | US/Indian English |
| Telugu | native conversational speech |
| Hindi | native conversational speech |
| Telugu+English | natural code switching |
| Hindi+English | natural code switching |
| Names | Krishna, Tejaswini, regional names |
| India places | Hyderabad, Khammam, Nalgonda |
| US places | Anchorage, Seward, Chicago |
| Speed | slow / normal / fast |
| Volume | normal / quiet |
| Environment | quiet room / car noise / fan |
| Fillers | um, uh, అంటే, मतलब |
| Repetition | "I, I don't know" |
| Slang | conversational phrases |
| Numbers | dates, amounts, phone-like digit sequences |

Use consented/synthetic test material, not private production recordings.

---

## 16. Evaluation

Track at least:

- **content WER** (case- and punctuation-insensitive) — the wording contract
- word/character error rate where meaningful — readability
- punctuation error rate — readability
- script preservation
- named-entity accuracy
- code-switch preservation
- unwanted translation rate
- unwanted rewrite rate
- empty/failure rate
- latency P50/P95

Because punctuation is now allowed (§2), raw WER alone can no longer tell "formatted" from
"rewritten": adding commas raises raw WER exactly as swapping words does. `contentWordErrorRate`
separates them — near-zero content WER with a higher raw WER is the *intended* outcome, and a rising
content WER is the contract breaking.

### Choosing the model and prompt

The V1 model is chosen from **measured product performance**, never from a model being newer or
generically recommended. Build one `BenchmarkArm` per (model × prompt variant) over the *same*
corpus and run `compareArms`: arms that fail the gate are excluded with their reasons recorded, and
the rest rank by content WER → punctuation error rate → median latency.

The arms to compare at minimum are the currently shipping `gpt-4o-transcribe` and the current
recommended alternative available to the project. `gpt-4o-transcribe` stays in production until a
run on the real corpus says otherwise.

### Release-blocking behavior

Even if overall WER is acceptable, release should be blocked if the system frequently:

- translates Telugu/Hindi to English
- collapses mixed-language speech into one language
- invents content during silence
- "improves" meaning
- loses large sections of speech

---

## 17. UX latency target

The user should receive immediate state feedback on Done.

Do not leave the interface frozen.

States:

```text
recording
   ↓
stopping
   ↓
transcribing
   ↓
inserted
```

If transcription is slow, the state should remain calm and explicit.

Never fake completion.

---

## 18. Official implementation references

OpenAI file transcription:
https://developers.openai.com/api/docs/guides/speech-to-text

OpenAI Realtime/audio overview:
https://developers.openai.com/api/docs/guides/realtime

OpenAI client secret / Realtime security reference:
https://developers.openai.com/api/reference/resources/realtime/subresources/client_secrets/methods/create/
