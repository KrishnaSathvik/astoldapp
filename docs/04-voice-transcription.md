# Voice Transcription Specification

## 1. Product role

Voice is not a separate note type.

It is an **input method inside the plain-text editor**.

After transcription, the resulting words become ordinary editable note text. V1 does not preserve a permanent "voice block" or recording object after successful transcription.

---

## 2. Verbatim Capture Contract

This is a core product contract.

The transcription path must **not intentionally**:

- translate speech
- summarize speech
- rewrite speech
- polish grammar
- change tone
- make sentences "more professional"
- remove slang because it sounds informal
- convert Telugu/Hindi to English by default
- replace the user's content with an AI-generated interpretation

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

**Record completed audio → send file → `gpt-transcribe` → insert final transcript.**

Reason:

- product does not require live words while user is still speaking
- completed-file transcription is simpler to reason about
- current OpenAI guidance recommends `gpt-transcribe` for recorded speech in its original language
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

### Done

- stop recorder
- close/finalize file
- validate non-empty recording
- show `Transcribing…`
- upload

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

Start with a configurable maximum voice capture duration (for example 10 minutes) to protect:

- latency
- memory/storage
- service cost
- accidental long recordings

Do not hardcode business limits deep in the view layer.

---

## 8. Cursor insertion contract

### Before recording

Capture the user's intended insertion selection/location.

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

Conceptual static instruction:

```text
Transcribe the recording faithfully in the original language(s).
Preserve English, Telugu, and Hindi code-switching as spoken.
Do not translate, summarize, rewrite, or improve grammar.
Prefer the native writing system for Telugu and Hindi when spoken.
Preserve natural repeated words, slang, names, and filler words where audible.
```

The exact prompt must be tested empirically.

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

Even punctuation changes should preferably come from the transcription model, not a rewrite pass.

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

- word/character error rate where meaningful
- script preservation
- named-entity accuracy
- code-switch preservation
- unwanted translation rate
- unwanted rewrite rate
- empty/failure rate
- latency P50/P95

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
