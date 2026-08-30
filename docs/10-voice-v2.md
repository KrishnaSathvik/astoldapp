# As Told Voice V2

> **Status: direction locked 2026-08-27. Implementation not started. Some behavior already shipped.**
>
> This is not a proposal awaiting a decision — the scope below was accepted, and its binding contracts
> now live in `RULES.md` §2 (Voice V2). `RULES.md` still wins on any conflict. Where a section restates
> behavior that already shipped in V1, it says so and `docs/04-voice-transcription.md` remains the truth
> for that behavior — this file MUST NOT become a second, drifting copy of the V1 voice spec.
>
> **Two things are refused and are not in Voice V2 at all:**
>
> - **§10 — self-correction removal.** Not built. No rule carve-out, no benchmark work. Revisit only
>   if real users ask for it, and only as a fresh rule change.
> - **§19 — the voice dictionary, local UI included.** Deferred out of the completion gate entirely,
>   because a dictionary that is never used as a hint does not improve transcription, and one that
>   silently substitutes words is a second word-changing system. It becomes a later experiment.
>
> Scope is closed so that Voice V2 can be **finished, tested, frozen, and shipped**. See §25.

---

## 0. The one sentence

> **Typing and speaking are equally easy ways to create or continue a note.**

And the contract does not move:

> **Preserve the words. Format the speech.** — and, where the writer explicitly asks for it,
> **structure the words.** Never *replace* them (`RULES.md` §2).

Voice V2 is not new capability bolted onto V1 voice. It is the removal of the friction between a
spoken thought and the note it belongs in. Every section below either deletes a step or protects
words that were already spoken.

---

## 1. The mental model — three entry points, one implementation

```text
HOME HEADER
As Told                              +   🎙
```

| Control | Means |
|---|---|
| `+` | **Write it.** New note by typing. Shipped. |
| `🎙` | **Say it.** New note by speaking. **New — §3.** |

Inside a note (shipped, refined by §8):

```text
[Aa]  [•]  [1.]  [☑︎]                    🎙
```

Later, from the system (§20):

```text
Action Button / Siri / Shortcut  →  New Voice Note
```

**There is exactly one Quick Capture implementation** with several entry points. A second capture
flow behind the Action Button is how the two drift.

### What this model forbids

- No separate **Voice** section, tab, or filter.
- No **Voice Notes** folder — folders are on the do-not-build list (`RULES.md` §7) and this would be
  one.
- No microphone badge, icon, or marker on a note row. A voice-created note is an **ordinary note**.
  Nothing in the model, the timeline, search, or export may record how a note's words arrived.

That last rule is the whole design. The moment a note remembers it was spoken, voice becomes a note
*type*, and As Told acquires a second document system — the thing `RULES.md` §2 exists to prevent.

---

## 2. What is already shipped — do not rebuild it

Voice V2 planning repeatedly rediscovers V1. This table is the guard against that.

| Behavior | Status | Owner |
|---|---|---|
| In-note mic, caret insertion | **shipped V1** | `RULES.md` §2 cursor insertion contract |
| No caret → append to end of note | **shipped V1** | `VoiceButton.appendsToEnd`, `Core/Voice/TranscriptInsertion.swift` |
| Nine structure commands + alias set | **shipped V1** (Milestone B) | `Core/Editor/VoiceStructure.swift`, `RULES.md` §7 |
| Natural punctuation / capitalization / paragraphs | **shipped V1** | `docs/04-voice-transcription.md` §9 (`punctuated` prompt) |
| No-speech, offline, service-failure, invalid-output errors | **shipped V1** | `docs/04-voice-transcription.md` §12 |
| One-time transcription disclosure | **shipped V1** | `Core/Voice/TranscriptionConsent.swift` |
| Microphone permission + Open Settings | **shipped V1** | `docs/04-voice-transcription.md` §12 |
| 5-minute recording cap, relay-authoritative | **shipped V1** | `docs/04-voice-transcription.md` §7 |
| 60 min / UTC month soft ceiling, no usage meter | **shipped V1** | `docs/04-voice-transcription.md` §14 |
| Five language groups + code-switching | **shipped V1** | `docs/04-voice-transcription.md` §3 |
| Call / Siri interruption finishes rather than discards | **shipped V1** | `VoiceCaptureModel.begin()` |
| Back mid-recording finishes rather than cancels | **shipped V1** (2026-08-19) | `VoiceCaptureModel.finishOnLeave()` |
| Recording panel replaces the writing toolbar | **shipped V1** | `Features/Voice/RecordingPanel.swift` |
| Home Quick Voice, transient until a transcript exists | **shipped V2 Phase 1** | `Features/Voice/QuickVoiceCaptureView.swift`, `QuickVoiceNote.swift` |
| Explicit capture states (§4), incl. `requestingPermission` / `paused` / `finishing` | **shipped V2 Phase 2A** | `VoiceCaptureModel.Phase` |
| Pause / resume, one continuous file | **shipped V2 Phase 2A** | `VoiceCaptureModel.pause()` / `.resume()`, `AudioRecording` |
| Recorded-duration accounting; the cap summed across pauses | **shipped V2 Phase 2A** | `Core/Voice/RecordedDuration.swift` |
| State announcements for VoiceOver (§6) | **shipped V2 Phase 2A** | `VoiceCaptureModel.Phase.announcement(from:to:)` |
| Retained recording after a retryable failure, Retry / Delete Recording (§13) | **shipped V2 Phase 2B** | `Core/Voice/RetainedVoiceRecording.swift`, `VoiceCaptureModel.retry()` / `.deleteRecording()` |
| Which failures may keep a recording (§13) | **shipped V2 Phase 2B** | `TranscriptionError.isRetryableVoiceFailure` |
| The 24-hour retry lifetime and its sweep (§13) | **shipped V2 Phase 2B** | `VoiceLimits.retryLifetime`, `AVAudioRecorderService.purgeAbandonedRecordings(in:now:keeping:)` |
| Backgrounding finishes rather than discards, from `recording` **and** `paused` (§14) | **shipped V2 Phase 2B** | `VoiceCaptureModel.finishOnBackground()` |
| Audio-route / Bluetooth handling (§14) | **shipped V2 Phase 2B** | `Core/Voice/AudioRouteChange.swift`, `AVAudioRecorderService` route observation |
| One-shot recovery of a recording that outlived its capture (§13) | **shipped V2 Phase 2B** | `Core/Voice/RetainedRecordingStore.swift`, `Features/Voice/RecoveredRecordingView.swift` |
| Leaving mid-upload retains rather than cancels-and-deletes (§13) | **shipped V2 Phase 2B** | `VoiceCaptureModel.finishOnLeave()`, `.isCurrentAttempt` |

**Still to build in V2:** the keyboard rule after quick capture (§7), voice into table cells (§11),
and the App Intent (§20).

That is the whole list. Nothing else is added, and the two refusals in the status block are not
partially, quietly, or experimentally in scope.

---

## 3. Home → Quick Voice

The most important flow in this document.

```text
Home
  ↓  tap 🎙
Listening immediately
  ↓  speak
Done
  ↓
Transcribing…
  ↓
an ordinary note opens
```

### What it MUST NOT do

```text
🎙  →  create a blank note  →  present the editor  →  raise the keyboard
    →  place a caret  →  begin recording
```

That sequence is the friction Quick Voice exists to delete. If the user must watch an editor appear
before the microphone opens, `+` and `🎙` are the same button with extra steps.

### The capture is transient until it earns a note

Quick Voice MUST NOT create a `Note` in SwiftData when the microphone opens. It creates a
**capture session**; a note is created only once a non-empty transcript exists.

```text
transient capture  →  transcript succeeds  →  create Note  →  open it
```

| Outcome | Result |
|---|---|
| Transcript returned | a normal note is created and opened |
| Cancel | nothing created, nothing written |
| Microphone denied | nothing created |
| No speech detected | nothing created, no allowance spent (§17) |
| Consent declined | nothing created, nothing uploaded |
| Transcription failed | nothing created; the **recording survives** (§13) |

The empty-draft purge (`Note.isEmptyDraft`, `RULES.md` §4) would eventually clean up notes created
the other way, but "eventually" is not the standard: a note that flickers into the timeline and out
again is a bug the user sees. Not creating it is simpler than sweeping it.

### The capture surface

```text
        Cancel


                    00:24

                  Listening

                  ▁▃▆▂▅▃▁


           Pause            Done
```

Top: **Cancel**. Middle: elapsed time, state word, audio-level bars. Bottom: **Pause** and **Done**.

MUST NOT appear on this screen: a title field, a keyboard, the writing toolbar, a full-screen Siri-style
animation, a language picker, a waveform that fills the screen, or any control not listed above.

The activity bars answer exactly one question — *is this thing hearing me?* — and carry no required
information (§6).

---

## 4. The recording state machine

V1 drives the panel from `VoiceCaptureModel.Phase` (`idle · permissionDenied · recording ·
needsConsent · transcribing · failed`). V2 adds pause, cancellation, and the durable-recording states,
and they MUST be explicit cases rather than booleans scattered across the view.

```text
idle
 ↓
requestingPermission ──► permissionDenied
 ↓
recording ⇄ paused
 ↓
finishing
 ↓
needsConsent  (first upload only, §16)
 ↓
transcribing
 ↓
success ─────────────────► note written, temp audio deleted
 ├─ noSpeech
 ├─ retryableFailure ────► recording retained (§13)
 ├─ limitReached
 └─ cancelled ───────────► temp audio deleted
```

Rules:

- The state machine is **shared** by Home Quick Voice, in-note voice, and the App Intent. One
  implementation, three presentations.
- Every transition is unit-testable without a microphone, a network, or a view — V1's injected
  `AudioRecording` + `TranscriptionService` seams stay.
- `recording` and `paused` MUST be distinguishable states, not `recording` plus an `isPaused` flag.
  The flag version is how a paused recorder ends up still counting time.

---

## 5. Pause / resume

```text
RECORDING                        PAUSED
        00:52                            00:52
      Listening                          Paused
Cancel   Pause    Done           Cancel  Resume   Done
```

- **The timer measures recorded audio, never wall-clock time.** Paused time does not count.
- The existing **5-minute maximum stays** (`docs/04-voice-transcription.md` §7) and applies to the
  summed recorded duration:

```text
record 2:30  →  pause 5 minutes  →  record 2:30   =  5:00 of voice
```

- At the cap, the recording **stops gracefully and proceeds to transcription**. This is the ordinary
  finish path, not a failure, and it MUST NOT lose the audio captured so far — identical to the V1
  cap behavior.
- **The relay stays the authority.** It measures duration from the container and rejects anything
  longer (`413 audio_duration_exceeded`). Pause/resume MUST produce a single continuous file whose
  container duration equals recorded time; if segments are concatenated, the concatenation happens
  before upload and the relay's measurement remains the number that counts. A client that reports
  4:59 for a 7-minute file is exactly what §7's "a client-reported duration is never trusted" is for.

> **Classification change — applied 2026-08-27.** `docs/09-v2-roadmap.md` §2.4 listed pause/resume and
> stronger interruption recovery as *later Pro voice work*. Both are now **Free** (§21). Pausing a
> recording is not a premium capability; it is how a recorder works, and paywalling it would make the
> free voice interaction deliberately worse — which §21 forbids. `docs/09-v2-roadmap.md` §2.4 carries
> the supersession note.

---

## 6. Feedback — haptics, waveform, VoiceOver

Haptics are small and mark only the moments the user is waiting on. V1 already does this via
`.sensoryFeedback` on the phase change; V2 keeps the same discipline for the new states.

| Event | Feedback |
|---|---|
| Recording actually starts | light |
| Pause / Resume | subtle |
| Done | subtle confirmation |
| Transcript inserted | subtle confirmation |

Nothing celebratory, nothing repeated, nothing on every second of the timer.

**Accessibility is a release blocker, not a polish item** (`RULES.md` §4):

- Every recording control has a VoiceOver label.
- State transitions are announced: *Recording started · Paused · Recording resumed · Transcribing ·
  Transcript added*.
- The timer is announced sensibly — on demand and at state changes, **never every second**.
- No control communicates its state through color alone.
- Dynamic Type is honored; touch targets meet the minimum.
- The waveform is decorative and MUST be hidden from the accessibility tree. If the only way to know
  the microphone is live is to see the bars move, the screen is broken for a VoiceOver user.

---

## 7. After Quick Voice — what the new note looks like

```text
‹        August 27, 2026 at 2:58        ⤴︎


I was thinking about going somewhere this weekend…
```

### The keyboard stays down

**Locked for this direction:**

> **Voice MUST NEVER summon a keyboard that was not already visible.**

The person chose to speak. Answering that by throwing a keyboard at them is the app overriding a
choice the user just made with their hands.

| Started voice with | After transcription |
|---|---|
| Keyboard down (Home Quick Voice, reading a note) | keyboard stays **down** |
| Keyboard up, actively editing | editing context preserved where practical |

If they want to type: tap the note. If they want to keep speaking: tap `🎙` again.

### No generated titles

Quick Voice produces:

```text
title = empty
body  = transcript
```

**MUST NOT** run any model to invent a title. That is `AI summaries` (`RULES.md` §7) wearing a
smaller hat, and it is a second interpretation layer over words the whole product promises to
preserve. Home already renders a titleless note from its first meaningful body line (`RULES.md` §4),
and it never generates `Untitled` — that existing behavior is the answer here.

A future explicit `title <words>` structure command is a legitimate candidate (it is the user asking,
which is the §2 test). It is **not** in Voice V2 scope and MUST NOT be built as part of it.

---

## 8. In-note voice 2.0

The insertion contract is shipped and unchanged (`RULES.md` §2):

> **Touch chooses where. Voice chooses what.**

| State when the mic is tapped | Where the transcript lands |
|---|---|
| Caret in the body | at the captured caret |
| No caret — reading, keyboard down | appended to the end |

Both cases ship today. What V2 changes is that **neither requires the keyboard**, and the second is
promoted from a fallback to a first-class flow:

```text
reading a note  →  tap 🎙  →  speak  →  Done  →  appended
```

No tap-into-body, no keyboard, no hunting for a caret.

### The toolbar morphs; the note stays visible

Unlike Home Quick Capture, in-note recording does **not** take over the screen — the user is already
inside a note and needs to see it.

```text
NORMAL     [Aa]  [•]  [1.]  [☑︎]                    🎙

RECORDING  Cancel          00:18          Done
                            ▁▅▃▆

PAUSED     Cancel          00:18         Resume
                                          Done
```

This is the V1 behavior (`RecordingPanel` replaces the writing toolbar, `RULES.md` §7) extended with
pause. The panel MUST stay contextual and MUST NOT grow a second row, a scroll, or an overflow.

### Repeated dictation must be cheap

```text
🎙  "first thought"           → Done → text appears
🎙  "another thing"           → Done → appended
🎙  "and one more thing"      → Done → appended
```

Each recording is a separate transaction, but the *interaction* must feel continuous. Between them
there MUST be no note creation, no keyboard raise-and-dismiss, no confirmation screen, and no language
selection. The consent sheet is once per install (§16), not once per recording.

---

## 9. Structure commands — shipped, verified, not extended

Milestone B shipped in V1. The vocabulary is **nine actions**, each with a closed alias set, parsed
deterministically on-device:

```text
new paragraph · new line · heading · subheading · bullet list
numbered list · checklist · next item · end list
```

Voice V2 adds **no new commands**. `RULES.md` §2 caps the vocabulary deliberately: it "MUST NOT grow
into dozens of commands, and MUST NOT use a generative model to *infer* what formatting the user
'probably' wanted."

Two rules worth restating because V2 work will be tempted to relax them:

- **Explicit exit exists and is an action, not a newline.** `end list` (and `stop list`, `normal
  paragraph`) does what Return on an empty item does — the marker goes, the line becomes a paragraph,
  and no empty marker is stranded. This is what keeps a list from swallowing the sentence after it:

```text
• Milk
• Eggs
I need to call Ravi tonight…        ← reached by "end list", never by guessing
```

- **Uncertain means literal.** A phrase becomes a command only when it is clearly isolated, at an
  utterance boundary, in exact supported wording, in a context where the action is valid. Otherwise
  it stays words. Conservative list inference is not a feature; explicit commands always win.

**Phase 4 of the build order is therefore verification, not construction** — see §23.

---

## 10. Corrections — **REFUSED. Not in Voice V2.**

The proposal: recognize explicit self-correction and resolve it.

```text
"Meeting at six — actually seven."     →  "Meeting at seven."
"Tuesday, sorry, Wednesday."           →  "Wednesday"
```

**This MUST NOT be implemented as specified.** It deletes words the speaker said, and that is the
one thing the product's central contract forbids.

`RULES.md` §2 — the transcription path MUST NOT *rewrite or paraphrase speech* or *replace vocabulary
with different words*. `docs/04-voice-transcription.md` §11 — allowed deterministic cleanup is limited
to **transport/UI artifacts** (a trailing newline, a doubled space at an insertion boundary). Removing
"at six — actually" is neither a transport artifact nor a punctuation mark; it is an edit, and the
worked example in §2 exists to draw exactly this line.

It is also the highest-risk item in the plan on its own merits:

- **The trigger words are ordinary words.** *actually*, *sorry*, *I mean*, *make that*, *correction*
  all occur constantly as content. "I'm sorry, Wednesday was awful" is not a correction.
- **The failure mode is silent deletion.** Every other voice failure in this product is loud and
  offers the user a choice. A false-positive correction removes content from a note with no error, no
  prompt, and no trace — and the user finds out later, if ever.
- **It is worst exactly where As Told is most differentiated.** Telugu/Hindi ↔ English code-switching
  already carries the highest transcription uncertainty; layering phrase-matched deletion on top of it
  puts the deletions where they are hardest to detect and least recoverable.
- **The safety rule already points the other way.** §9's parser resolves ambiguity by *preserving the
  spoken words and taking no action*. Corrections would be the first voice feature to resolve ambiguity
  by removing text.

### The decision (2026-08-27)

**Do not build correction removal.** No `RULES.md` §2 carve-out is drafted, and no benchmark work is
scheduled. This is not "blocked pending evidence" — nobody is gathering the evidence, because the
behavior is not wanted.

What ships instead is nothing at all. If someone says:

```text
Meeting at six — actually seven.
```

As Told stores:

```text
Meeting at six — actually seven.
```

That is a correct, readable note that says exactly what the person said, and it is a completely
acceptable outcome for this product. The words are already there and already punctuated; the contract
already endorses leaving them alone; and it costs nothing to ship.

**Reopening this** requires real users asking for it in numbers — not a hunch, not a competitor
shipping it. If that ever happens it starts over as a fresh rule change, and the bar it would have to
clear is a measured **unwanted-deletion rate per language group**, because content WER measures wrong
words and not missing ones. Nothing about that work is begun by this document.

---

## 11. Voice inside tables

Table display shipped 2026-08-21 and cell editing followed (`RULES.md` §7, tables exception). Voice
should reach a cell the same way typing does — through the caret, with no new concepts.

```text
┌─────────────┬─────────┐
│ City        │ Nights  │
├─────────────┼─────────┤
│ Fairbanks   │ [   ]   │      ← active cell
└─────────────┴─────────┘

tap 🎙 → "four" → Done
```

```text
│ Fairbanks   │ 4       │
```

Rules:

- **The active cell is the destination.** This is `Touch chooses where` applied unchanged; no new
  targeting mechanism, no "put this in the Nights column" voice syntax.
- **No pipe source reaches the microphone path and none is produced by it.** How a table is stored is
  implementation (`RULES.md` §7); voice writes cell content, not Markdown.
- **The ordinary table commit/undo lifecycle applies.** A cell edit is one undo step through the text
  view's own edit primitive (`Features/Editor/BodyTextView.swift`); a spoken cell edit MUST route
  through that same primitive rather than a second path that happens to agree today.
- **Structure commands are invalid inside a cell** and MUST stay literal there — a table cell is not a
  place a bullet list can begin. This is §9's "in a context where the action is valid" doing its job.

---

## 12. Code blocks — explicitly out of scope

Speech may be inserted into an active code block as ordinary text. That is all.

**MUST NOT build** spoken-syntax dictation — `open parenthesis`, `string quote`, `camel case`,
`semicolon`, indentation commands. That is a different product with a different vocabulary, a
different error model, and a command set that cannot stay small (§9). It is out of scope for Voice
V2 and MUST NOT be started as part of it.

---

## 13. Durability — a recording is never casually lost

The failure this section exists to make impossible:

```text
speak for four minutes  →  network error  →  gone
```

### The model

The finished recording stays on-device until **transcription succeeds** or **the user explicitly
discards it**.

```text
Couldn't transcribe this recording.

Your recording is still on this iPhone.

    Retry            Delete Recording
```

On success, the temporary audio is deleted **immediately** — As Told does not become an audio
recorder or an archive (`RULES.md` §7 excludes `audio archive`; keeping original audio is a §7 P1
candidate, off by default, and is **not** this).

### Reconciling with the temp-audio rules

`RULES.md` §3 requires temporary audio to be deleted on Cancel, on successful transcription, and on
Discard, and abandoned files to be swept at launch "beyond the allowed retry lifetime." V2 does not
weaken that; it **defines the lifetime**, which today is implicit:

- A retained recording lives in the same app-controlled, file-protected, randomly-named location it
  already uses. It MUST NEVER reach Photos or shared Documents.
- It is retained **only** after a retryable transcription failure — never after Cancel, never after
  success, never after no-speech, never after a declined consent prompt.
- **The retry lifetime is 24 hours** (locked 2026-08-27). Long enough for temporary network or service
  trouble to clear and for someone to come back to it later the same day; short enough that As Told is
  never quietly accumulating audio. It MUST be a named constant beside the other voice limits
  (`voiceRetryLifetime`), never a number in the view layer (`docs/04-voice-transcription.md` §7).

```text
launch
  → a retained recording older than 24 hours
  → delete
```

- **It is never uploaded without explicit user intent.** No background retry, no queue that drains on
  reconnect (`RULES.md` §2). Retry is a tap.
- **`Delete Recording` is the only management affordance.** There is no recordings list, no playback,
  no rename, no export.

### "One retry" means one affordance, not one attempt

Precisely: **one retained recording, one Retry affordance, one Delete affordance.**

The same Retry button MAY be tapped again after another retryable failure, and again after that, until
one of three things ends it — **success**, **explicit deletion**, or the **24-hour expiry**.

It MUST NOT mean the user gets a single network attempt:

```text
record 4 minutes  →  network fails  →  Retry  →  fails again  →  audio deleted   ❌
```

That is the exact data loss this whole section exists to prevent, arriving one attempt later than the
version it replaced. A flaky connection is the *normal* reason a retry is needed, and the second
attempt is the one most likely to succeed.

What stays forbidden is unchanged by this: no recordings list, no queue, no archive, no automatic or
background retries. Two controls, and nothing else:

```text
    Retry            Delete Recording
```

### Where the recording is offered back

A Quick Voice failure has no note to return to, so the retry lives on the capture screen. An in-note
failure keeps the existing panel behavior. Either way the user is told the audio is safe, in those
words, because "Couldn't transcribe" alone reads as *your words are gone*.

**And afterwards, once, from Home** (decided 2026-08-28). Neither Back nor the app closing is one of
the three things allowed to end a recording, so neither may be what deletes it:

```text
retryable failure
   → retain
   → Retry · Delete Recording · app closes · user navigates away
   → until success, explicit deletion, or 24 hours
```

If As Told launches — or returns to Home — and finds a valid retained recording younger than 24 hours,
it offers it back on one surface:

```text
We saved a recording that couldn't be transcribed.

    Retry            Delete Recording
```

Dismissing that without choosing keeps the recording; it is offered again next launch. Nothing about
recovery is a deadline, because a deadline is another way to lose audio.

What recovery may **not** grow into is the same list as everything else here: no recordings list, no
playback, no name or date on screen, no history, no export, no background upload. One recording, two
controls. The launch sweep becomes exactly:

```text
valid retained recording  < 24h   → keep, and offer it back
retained recording       >= 24h   → delete
anything else in temp             → delete
```

The upload is inside that rule, not beside it. Leaving the note while the transcription is still in
flight:

```text
Done → Transcribing… → Back
   → claim the recording (retain + remember)
   → abandon the attempt
   → Home offers it back
```

Never the two obvious wrong answers — deleting the audio, or letting an invisible upload finish and
try to reach an editor that no longer exists. A late answer from the abandoned attempt is dropped
before it can touch anything, which needs an attempt **identity** rather than task cancellation alone:
a request that has already reached the relay comes back regardless, and a late `no_speech` would
otherwise delete the very recording the recovery surface is about to offer.

A recording captured inside a note keeps its insertion point only while that editing session lives.
After the process ends the caret is meaningless — the note may have changed — so a recovered transcript
becomes a **new ordinary note**, said in the copy before the retry, not discovered after it. No
`UITextView`, caret, or editor internal is ever persisted.

---

## 14. No speech, offline, interruptions, backgrounding

### No speech (shipped)

```text
We didn't hear anything.

    Try Again        Cancel
```

MUST NOT create a note, MUST NOT modify an existing note, and MUST NOT spend allowance —
`no_speech` is refunded server-side (`docs/04-voice-transcription.md` §14).

### No connection (shipped, extended by §13)

```text
Couldn't connect to transcription.

Your recording is still on this iPhone.

    Retry
```

### Interruptions

Each of these MUST be handled explicitly before Voice V2 is called finished:

- incoming call or other audio interruption (**shipped** — finishes with audio captured so far)
- Siri activation (**shipped**)
- Bluetooth / AirPods **disconnect** mid-recording (**shipped 2B** — finishes safely with what was
  captured; losing the active input is not something to continue through on a guess)
- Bluetooth / AirPods **connect** mid-recording (**shipped 2B** — the recording continues, because
  nobody's microphone should change mid-sentence because a case was opened nearby)
- audio route changes (**shipped 2B** — `AudioRouteChange` decides, on route semantics rather than
  product names; still to be confirmed on hardware, §25)
- app backgrounding (**shipped 2B** — finishes from `paused` as well as `recording`)

The safe default in every case:

```text
interrupted  →  pause or finish safely  →  keep the captured audio  →  say what happened
```

**MUST NOT** record indefinitely in the background to be clever about it. A continuous background
listener is on the do-not-build list, and the audio-session configuration required for it is not
worth the product it turns As Told into.

### Backgrounding

**Backgrounding MUST NEVER equal discard.** Whether the recorder continues where iOS explicitly
supports it, or pauses and shows `Recording paused` on return, is an implementation decision made
against the real audio-session behavior during Phase 2 — but the captured audio survives either way.
V1 already finishes-and-transcribes on backgrounding; V2 MUST NOT regress that.

**Decided in 2B: it finishes.** As Told does not ask iOS for the background audio mode a continuing
recorder would need — that is the continuous listener the do-not-build list excludes — so leaving
closes the microphone and sends what was already said, from `paused` exactly as from `recording`
(`VoiceCaptureModel.finishOnBackground`). Everything else backgrounding touches is left alone: an
upload in flight keeps going, and a retained recording stays retained.

---

## 15. Undo

One completed transcription insertion is **one ordinary undoable edit**.

```text
speak 40 seconds  →  transcript inserted  →  Undo  →  the whole transcription disappears
```

Not one undo step per sentence, per paragraph, or per structure command applied within a single
transcript. This matches the shipped rule for the Style menu — "applying a style acts on every line
the selection touches, as one undo step" (`RULES.md` §7) — and it goes through the same document-action
layer for the same reason: one operation underneath, never two formatting systems.

For a table cell, the ordinary table commit/undo semantics apply unchanged (§11).

---

## 16. Permission and consent — shipped, restated

Two separate gates, and they MUST stay separate. The microphone permission covers **recording**; it
does not cover **sending**.

**Microphone (system prompt, first use).** If denied:

```text
Microphone Access

As Told needs microphone access to record a voice note.

    Open Settings        Cancel
```

MUST NOT re-trigger a system prompt iOS will not show again.

**Transcription disclosure (once per install, after Done, before the first upload).**

```text
Voice Transcription

To turn your recording into text, As Told securely
sends this recording to OpenAI.

Your existing note text is not sent.

    Cancel               Continue
```

- Recording locally sends nothing.
- Cancel before transcription → nothing is uploaded, and the audio is deleted.
- Existing note content is **never** sent with the audio (`docs/04-voice-transcription.md` §9 — the
  critical privacy rule).

Quick Voice reaches this gate at the same point in the flow: after Done, before the first upload,
with the audio held unread on disk while the question is open.

---

## 17. Limits — shipped, unchanged

| Control | Value | Protects against |
|---|---|---|
| Per recording | **5 minutes** | one runaway request; latency, memory, retry cost |
| Per UTC month | **60 minutes**, soft ceiling | sustained cost |
| Rate | 20 requests / minute | scripted bursts |

Same allowance regardless of language. **No visible usage meter, credit count, progress bar, or
Profile usage screen** — the ceiling is a cost boundary, not a feature.

When the allowance is exhausted, the next microphone tap is refused **before the recorder opens**,
using the reset date the relay reported on the successful recording that crossed the ceiling:

```text
Voice will be back soon

You've used this month's included voice transcription. You can keep
writing normally, and voice will be available again on <date>.

    OK
```

No Retry (the same upload would be refused) and **no upgrade call to action inside someone's note**.
Voice V2 MUST NOT introduce one.

---

## 18. Languages — shipped, unchanged

English · Telugu · Hindi · Telugu + English · Hindi + English · natural code-switching.

```text
"Tomorrow morning temple ki vellali and then Costco ki vellali."
```

Stays mixed, because the person spoke mixed. Telugu → Telugu script, Hindi → Devanagari, English terms
preserved inside mixed speech. **MUST NOT translate.** Language hints stay benchmark-driven, never
assumption-driven, and a single language MUST NOT be forced on every recording.

---

## 19. Voice dictionary — **DEFERRED. Not in Voice V2, local UI included.**

The idea: a user-managed list of names, places, brands, acronyms, and technical vocabulary — the terms
a general model reliably gets wrong and a user reliably repeats.

```text
Settings ▸ Voice          TrailVerse · Khammam · Databricks · PySpark
```

**Removed from the Voice V2 completion gate entirely** (2026-08-27), including the local list UI.
Not "build the local half now, decide the server half later" — none of it.

### Why the local half does not stand alone

A dictionary earns its place only through one of two mechanisms, and both are out of scope:

```text
User adds "TrailVerse"
        ↓
   stored locally
        ↓
       ???
```

1. **Send it as a transcription hint.** That puts a new category of personal data on the wire with
   every recording, which `RULES.md` §3 does not permit and this document is not amending.
2. **Substitute after transcription.** `Trail Worse → TrailVerse` is a second word-changing system
   inside a product whose central contract is that words are not changed. It would need its own safety
   rules, its own ambiguity handling, and its own false-positive metric — the same objections that sank
   §10, in a different costume.

Without one of those, the dictionary is a settings screen where terms go to be stored and nothing
happens. Shipping it would let people *believe* they had improved their transcription while nothing
had changed, which is worse than not offering it.

### What is deferred to

A single, separable experiment, run whenever it earns priority:

> Does the transcription provider's prompting/hint capability improve proper-name accuracy enough to
> justify sending custom vocabulary off the device?

It is answered on the consented benchmark corpus (`docs/04-voice-transcription.md` §15), not by
intuition. **If yes**, the feature is then designed deliberately — hints, disclosure, a `RULES.md` §3
amendment naming exactly what is sent, and a privacy-policy update, in that order. **If no**, there is
nothing to build and the question is closed.

Until then: **MUST NOT** ship a dictionary UI, and **MUST NOT** silently begin transmitting anyone's
vocabulary.

---

## 20. System Quick Capture

Once Home Quick Voice is stable, expose **the same capture flow** through one App Intent.

```text
New Voice Note
```

Surfaces: Shortcuts · Action Button · Siri · Control Center / Lock Screen where iOS permits.

```text
WANTED                        NOT THIS
Action Button                 Action Button
  ↓                             ↓
As Told opens                 As Told Home
  ↓                             ↓
Listening                     tap the mic again
```

> "Siri, start a voice note in As Told."

**One Quick Capture implementation, multiple entry points** (§1). A second flow behind the Action
Button is a second thing to keep correct.

### Preconditions

- **The App Intent MUST NOT bypass the app lock** (`RULES.md` §3). If lock is enabled, authentication
  comes first and the pending capture is held until it succeeds — the same requirement the post-V1
  note-reminder direction carries for notifications.
- This is the `Lock Screen / Control Center quick capture` P1 candidate in `RULES.md` §7 being
  promoted, not a new direction.
- Marketing MUST NOT claim it before it ships (`RULES.md` §7, marketing lags implementation).

---

## 21. Free vs Pro

**Everything that makes voice good is Free.**

| Free | Pro |
|---|---|
| Home Quick Capture | |
| In-note voice | |
| Pause / Resume | |
| Retry and recording durability | |
| Structure commands | |
| Multilingual speech + code-switching | |
| Table-cell voice | |
| System shortcuts (Action Button / Siri) | |
| 60 min / UTC month | **Expanded Voice** — a larger monthly allowance |

> **The free voice interaction MUST NOT be made deliberately worse to create a Pro upsell.**

Pro is capacity, and nothing else. The Pro allowance stays deliberately unchosen until real V1
economics exist — median and 90th/95th-percentile minutes, cost per active voice user, and how many
users ever approach the free ceiling (`docs/09-v2-roadmap.md` §2.4). This is the only Pro feature
with a direct per-minute cost, so it is the one that decides the price.

---

## 22. What Voice V2 is not

```text
❌ self-correction deletion (§10)        ❌ a meeting recorder
❌ a voice dictionary (§19)              ❌ an audio-note library
❌ server-side vocabulary hints (§19)    ❌ a continuous background listener
❌ a system-wide dictation keyboard      ❌ speaker diarization
❌ an AI email writer                    ❌ voice-to-code dictation
❌ a rewriting assistant                 ❌ automatic translation
❌ a tone changer                        ❌ AI-generated titles
❌ a summarizer                          ❌ new structure commands
```

The first three rows are the scope decisions made on 2026-08-27; the rest were never in. This list is
the reason Voice V2 can be **finished**. Without it, voice becomes a permanent feature-chase against
products solving a different problem.

---

## 23. Build order

### Phase 1 — Quick Voice foundation ◻

Home header `🎙` → capture screen → Record / Cancel / Done → transcribe → create note. Establish the
shared state machine (§4).

**Done when:** Home → speak → a normal note, with nothing left behind on any failure path.

### Phase 2 — Recording controls and resilience ✅ shipped (2A + 2B, 2026-08-28)

The explicit state machine (§4), timer, subtle audio activity, Pause/Resume with recorded-time
accounting (§5), the 5-minute cap across pauses, no-speech, retained recording with the 24-hour
lifetime and a reusable Retry (§13), permission handling, network failure, Bluetooth/AirPods route
changes, interruptions, and backgrounding (§14).

The state machine is the load-bearing part: it is what stops the recorder from becoming a pile of
`isRecording` / `isPaused` / `isRetrying` flags that disagree with each other.

**Done when:** you cannot casually lose a recording.

**Built.** 2A shipped the state machine, pause/resume, and the recorded-duration cap. 2B shipped the
rest: a retryable failure keeps its recording (`isRetryableVoiceFailure` decides which failures those
are, once, centrally), **Retry** may be tapped again after each further failure until success or
deletion, the 24-hour lifetime is a named constant with a sweep behind it, backgrounding finishes from
`paused` as well as `recording`, an input that disappears mid-recording finishes safely through the
same path a phone call already took, and a retained recording survives both Back and the app closing —
offered back once, from Home, with the same two controls.

### Phase 3 — In-note voice 2.0 ◻

Toolbar morph with pause; keyboard rule enforced (§7); one insertion = one undo step (§15). The
caret/append contract is already shipped — this phase verifies it and removes the keyboard from the
path.

**Done when:** voice continues any note without typing first.

### Phase 4 — Structure verification ✅ mostly shipped

The nine commands and their aliases shipped in V1 (§9). **No new commands.** This phase is
verification against the new entry points — do commands parse identically from Quick Voice as from
in-note capture? Corrections (§10) are refused, so nothing else lands here.

**Done when:** a spoken structure behaves identically regardless of which entry point started the
recording.

### Phase 5 — Structured editor integration ◻

Table-cell voice (§11), focus restoration, table undo semantics, lists and checklists, safe behavior
inside code and preformatted blocks (§12).

**Done when:** voice and the editor architecture do not fight.

### Phase 6 — System Quick Capture ◻

One App Intent, several surfaces, app-lock precondition satisfied (§20).

**Done when:** the user reaches Listening without navigating the app.

### Phase 7 — Device verification, then freeze ◻

**Not the dictionary** — that left the gate (§19). This phase is the real five-language session on a
real iPhone and the accessibility pass, both specified in §24, followed by the freeze.

**Done when:** every item in §24 is green, and voice is frozen.

---

## 24. Release gate — Voice V2 is not complete until all are true

### Automated

Unit tests covering:

- every recording state transition (§4)
- pause/resume duration accounting, including the 5-minute boundary across a pause
- Cancel at each state leaves no note and no audio
- Quick Voice creates a note on success and **no** note on cancel, no-speech, denial, or failure
- a retryable failure retains the audio; success and discard delete it; the launch sweep clears
  anything past the retry lifetime
- cursor insertion, no-cursor append, and table-cell insertion
- one transcription = one undo step
- structure commands parse identically from every entry point
- monthly limit refusal before the recorder opens, with the relay's `resetsAt`
- consent gate: declined uploads nothing and deletes the audio
- microphone denial path
- interruption lifecycle keeps captured audio

UI tests for the deterministic state and presentation behavior, against the fake transcription
service (`Core/Voice/FakeTranscriptionService.swift`) — the Phase 8 discipline from
`docs/07-build-plan.md` still applies.

### Accessibility

Every item in §6, verified with VoiceOver actually running.

### Physical-device session — this matters more than the simulator

Speak all five groups on a real iPhone: **English · Telugu · Hindi · Telugu + English · Hindi +
English**.

For each: Home Quick Capture · existing-note append · cursor insertion · Pause/Resume · a longer
2–4 minute passage.

And exercise: AirPods · device microphone · Dark and Light · an interrupted recording · a network
failure and retry · the first permission prompt · the first consent prompt.

Then use Quick Voice during ordinary life for several days. That catches what tests cannot.

### Then freeze it

Once this gate is green, **voice freezes the way the editor froze.** No open-ended feature chase.
A complete voice-note experience that belongs to As Told.

---

## 25. Decision record

**Rows 1–7 are accepted and binding.** Their contracts live in `RULES.md` §2 (Voice V2); this file is
the detail, not the authority. Rows 8 and 9 are refused and nothing about them is in progress.

| # | Change | Status | Where |
|---|---|---|---|
| 1 | Home header gains a mic control, beside `+` | **ACCEPTED** | `RULES.md` §2, §4 (Home) |
| 2 | Voice may create a note, not only write into one; the capture is transient until a transcript exists | **ACCEPTED** | `RULES.md` §2 |
| 3 | Pause/resume, with the timer measuring recorded audio and the 5-minute cap summing across pauses | **ACCEPTED** | `RULES.md` §2, `docs/04-voice-transcription.md` §7 |
| 4 | Retained recording after a retryable failure: **24-hour** lifetime, reusable Retry, explicit-intent-only upload | **ACCEPTED** | `RULES.md` §2, §3 (Temporary audio) |
| 5 | Voice MUST NEVER summon a keyboard that was not already visible | **ACCEPTED** | `RULES.md` §2, §4 |
| 6 | Pause/resume and interruption recovery reclassified **Pro → Free** | **ACCEPTED** | `docs/09-v2-roadmap.md` §2.4 |
| 7 | `Lock Screen / Control Center quick capture` promoted from P1 candidate, app-lock precondition intact | **ACCEPTED** | `RULES.md` §2, §7 |
| 8 | Self-correction removal | **REFUSED** — no carve-out drafted, no benchmark scheduled (§10) | — |
| 9 | Voice dictionary, local UI and server hints alike | **REFUSED / DEFERRED** — a later experiment, outside the gate (§19) | — |

Rows 8 and 9 required rule amendments that were **not** written. That is the point: refusing them cost
nothing, and it is what makes the remaining scope finishable.

### One pre-existing correction — applied 2026-08-27, unrelated to V2

`RULES.md` §2 read *"Leaving the editor mid-recording MUST cancel the capture and delete the temporary
audio."* That was reversed on 2026-08-19 — Back finishes and transcribes, because deleting audio the
user had already spoken was a data-loss bug (`docs/04-voice-transcription.md` §6,
`VoiceCaptureModel.finishOnLeave()`). The rule file had not followed the spec for eight days, and §13
of this document builds directly on the corrected behavior, so the drift was fixed rather than
inherited. **This is the only change in this batch that alters a rule about shipped behavior**; every
other line in the table above is a proposal awaiting a decision.

---

## 26. References

- `RULES.md` §2 (voice and verbatim capture), §3 (privacy), §4 (UI/UX), §7 (do-not-build, Milestones A/B)
- `docs/04-voice-transcription.md` — the V1 voice contract, and the truth for everything marked shipped
- `docs/09-v2-roadmap.md` §2.4 — Expanded Voice, the Free/Pro split
- `docs/02-features.md` — Voice acceptance criteria
- `docs/03-design-system.md` §4.7–4.8 — mic control and recording surface
