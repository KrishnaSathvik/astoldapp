# RULES — As Told

> The single source of truth for **what must and must not happen** in this product.
> When any doc, ticket, or instinct conflicts with a rule here, this file wins unless
> the rule is intentionally changed (and this file is updated in the same change).
>
> Every rule links back to the spec that owns the full reasoning. If you are unsure,
> read the linked spec — do not guess.

**Primary product rule**

> **The note is always more important than the interface.**
> If a decision makes the interface more visible while making writing slower, noisier,
> or more complicated, it is probably the wrong decision.

---

## 0. How to use this file

- Rules are grouped by area. Each rule is written as an absolute **MUST** / **MUST NOT** / **DO NOT**.
- "V1" means the first shippable version. Rules marked _(V1 only)_ are scope decisions that may
  be revisited later; all other rules are product/privacy/security contracts.
- Spec references: `docs/01-product-requirements.md` … `docs/07-build-plan.md`.

---

## 1. Locked product constraints (V1)

Source: `README.md` §2, `docs/01-product-requirements.md` §6.

These are treated as fixed product constraints unless intentionally changed.

- MUST NOT require an account or any sign-in (no Sign in with Apple).
- MUST NOT show an onboarding carousel. Exactly **one** first-run welcome screen.
- Tagline is **"Write it. Say it. Keep it."** and MUST NOT change.
- Primary descriptor is **"A private place for anything you want to put into words."** (Repositioned
  2026-08-18 from the thoughts-only framing — this widens the *invitation*, not the *product*. See
  `README.md` §2 and `docs/08-positioning-marketing.md`.) The product still refuses to become Notion /
  Todoist / Word / an AI writing assistant; the do-not-build fences in §7 hold.
- **Home is the recent chronological notes surface, not the complete archive.** Home shows `Today`
  and `Previous 7 Days`, under the caps below. When — **and only when** — notes exist outside that
  recent surface, Home exposes **one** archive affordance, labelled `Browse older notes` with a
  disclosure indicator, leading to the complete chronological timeline (the screen it opens is
  titled `All Notes`). If every note in the library already sits in `Today` or `Previous 7 Days`,
  there MUST be no archive affordance at all: `Show all N` has already exposed the complete library,
  and a second control leading to the same notes one screen further away is the same offer made
  twice. A period merely being *capped* is not a reason to draw it.
  (Changed 2026-08-31. The affordance was unconditional and named `View All Notes` for part of that
  day; it sat under a `Show all 14` that reached the same fourteen notes, and the two read as the
  same offer twice. It is now named for why you would tap it rather than for what the next screen is
  called. The previous rule required Home to *be* the complete timeline; it was written when a library was a handful of notes, and at a few hundred — especially
  with a run of untitled voice captures, which have no title to scan past — Home stopped being a
  place to land and became the database. The mental model is now four surfaces with four questions:
  Home *what was I working on recently*, All Notes *show me everything*, Calendar *what did I write
  that day*, Search *where is that note*. Rationale in
  `docs/plans/2026-08-30-home-library-redesign-design.md`.)
- **All Notes is an extension of Home, not a second organization system.** It MUST use the same
  chronological period grouping and the same note-row presentation. It MUST NOT add its own search,
  sort, filter, alternate layout, folders, counts, or any other browsing model. This is the calendar
  day list's fence, applied to the one other surface that lists notes — the moment either grows a
  control Home did not give it, As Told has a second notes browser. (Added 2026-08-31.)
- Each Home period MUST be capped — **4** for `Today`, **5** for `Previous 7 Days` — with a quiet
  `Show all N` that expands **that period in place**, where `N` names the whole period and never the
  remainder. The cap keeps the newest; a period inside its cap MUST NOT draw the affordance at all;
  and the cap is a rule about **presentation**, never about the query — a storage batch boundary MUST
  NOT be able to become a UI rule by accident. Expansion MUST last for the visit: opening a note from
  an expanded period and coming back MUST NOT re-collapse it. It need not survive a launch.
  (Added 2026-08-31.)
- **`Show all N` MUST be reversible.** An expanded period MUST offer `Show less` — the same control,
  in the same place — returning it to its cap for the rest of the visit. A period that never reached
  its cap MUST NOT draw either label. (Added 2026-08-31: expansion that only went one way turned a
  fourteen-row `Previous 7 Days` into a wall with no way back short of leaving Home, which made a
  glance feel like a commitment. `Show less` is not pagination running backwards — it restores a
  presentation rule, and reveals nothing.)
- Home MUST lead with the **subtle current date**, sitting on the first period heading and appearing
  exactly once. It MUST NOT print the app's name, and it MUST NOT print a count of the library.
  (Restored 2026-08-31, the same day an `As Told` title over `N notes` briefly replaced it. The name
  of the app is on the icon the reader just tapped; the count is a statistic, and §4 forbids Home
  from showing statistics outright; and together they cost a large block of the screen above the
  first note. The date is small, tertiary and all-caps — it orients rather than announces, which is
  why it does not compete with the `Today` heading under it.)
- Notes MUST be grouped automatically by **relative period** on Home — `Today`, `Previous 7 Days`,
  `Previous 30 Days`, `Older` — with a period drawn only when something landed in it. (Changed
  2026-08-30, replacing "grouped automatically by day". Day buckets were correct and unscannable:
  a library of several hundred notes carried roughly as many date headings, and a heading that
  appears once per note has stopped being information. Boundaries are inclusive and counted in whole
  **calendar** days — never 24-hour math. The **calendar** still groups by day and still names the
  day; reaching a date and browsing a timeline are different questions.)
- Home MUST NOT expose page numbers, batches, cursors, repeated `Load more` controls, or any other
  user-facing pagination. A period-level `Show all N` / `Show less` affordance **is permitted** when
  Home intentionally previews only part of that period: it toggles that period between its cap and
  its whole self, revealing only notes already belonging to it. It is not pagination — there is no
  next batch, and pressing it twice returns to where it started. All Notes MAY fetch older notes internally while
  scrolling, but that loading MUST remain invisible — no page numbers, batch counts, `Load more`, or
  repeated continuation controls. (Clarified 2026-08-31; the original prohibition is unchanged in
  spirit and in what it forbids.)
- Search MUST be available from Home via native pull-down/`.searchable` behavior.
- Calendar is a **secondary** navigation tool for reaching a date — not a second database UI.
  Selecting a day lists that day's notes **on the calendar itself**, and opening one returns there
  (changed 2026-08-19, replacing the day-filtered Home mode). The fence that keeps it from becoming
  a second browsing surface: the day list is rows and nothing else — no search, no sort, no
  grouping, no pagination, no counts, the same `NoteRow` Home uses. (The complete timeline moved
  behind **Browse older notes** on 2026-08-31, under the same fence; the calendar is still not it.)
- **The calendar page MUST have exactly one vertical scrolling surface.** The month grid, the selected
  day's heading, its notes, and the way past their cap all scroll together. A nested scrolling notes
  list MUST NOT be reintroduced. (Added 2026-08-31, fixing it: the grid sat above a `List` that
  scrolled inside it, so a day with eleven notes gave the reader two stacked scroll views and no way
  to know which one a drag would move.)
- The selected day MUST show at most **4** notes, with the same reversible `Show all N` / `Show less`
  Home uses, in the same words. Four rather than Home's five because the grid above it is tall.
  Expansion resets when the selection moves and need not survive leaving the screen. (Added
  2026-08-31.)
- The selected-day heading is `Today` when today is selected, and otherwise the weekday **and** date
  (`Saturday, August 29`) — never the timeline's relative `Yesterday`, because the reader has pointed
  at a square on a grid. **No count beside it.** (Added 2026-08-31.)
- **A day's note indicator MUST NOT become a count.** At most **three** dots — 1 note, 2–3, 4+ — as a
  sense of activity only. No numerical badge, no heatmap, no per-note-type colour, no voice or
  checklist icon, and nothing else that distinguishes notes the `Note` model does not actually
  distinguish. A voice-created note is an ordinary note. The dot count is visual shorthand; the
  accessibility value MUST speak the **exact** number, since state is never carried by colour alone
  (§4). (Added 2026-08-31.)
- Note title MUST be optional. MUST NOT ever render `Untitled`.
- Empty notes (no meaningful title or body) MUST be discarded automatically.
- Home MUST NOT show note creation times on normal rows.
- **A note's body MUST NOT visually masquerade as a title.** A row draws a title line **only** when
  `title` holds visible text; that line is the sole thing rendered in the primary/semibold treatment,
  and it means one thing — *the writer named this note*. A titleless note MUST NOT have its first
  body line promoted into that slot: the row draws **no title line at all**, and its body is rendered
  as an ordinary excerpt in secondary body text. `Untitled`, `Voice Note`, a generated title, and a
  badge all stay forbidden — the absence of a title is the answer, not something to fill in. A
  voice-created note with no title is an ordinary titleless note and takes the same row.
  (Tightened 2026-08-31, twice in one day. First semibold, then **medium**, were tried on the
  promoted first line; both were the same mistake in different amounts. Any extra weight on a body
  line reads as a heading, so a column of voice transcripts looked like a list of names nobody wrote.
  Weight now belongs to titles exclusively.)
- A row's body excerpt MUST be limited to **two** lines, the same limit for every row, so truncation
  is deterministic and never depends on what happens to fit. It carries the **whole** body: a
  titleless note no longer spends its first line paying for a title it never had. (Changed
  2026-08-31 from one line — a single orphaned sentence read as a headline and left a section
  looking sparse while its notes had more to say.)
- Untitled body text MUST be clearly readable and visually **subordinate to a real title**, and MUST
  NOT look disabled. Colours come from the semantic tokens (`textPrimary` for a title,
  `textSecondary` for an excerpt), never from a hard-coded grey, and the hierarchy MUST read
  correctly in both Light and Dark. (Added 2026-08-31.)
- Editor shows the note **date**, not a prominent time.
- Notes MUST autosave. MUST NOT show a Save button — and MUST NOT show a `Done` either. A control
  that ends editing implies that not pressing it loses work, which is the belief autosave exists to
  make false. Removed 2026-08-19 after a user lost a note to exactly that belief. The keyboard leaves
  by scrolling the body interactively or by navigating Back; **Back always saves.**
- Writing controls live in **one contextual floating toolbar above the keyboard** (`WritingToolbar`),
  never in a bar across the top of the writing area. Light structure — headings / subheadings / bullet /
  numbered / checklist — **shipped in V1** (§7) and is created three equivalent ways: tapping it in
  the writing toolbar, typing its marker, or speaking its command. All three route through
  the one `DocumentAction.setBlockKind` primitive; there is never a second formatting system.
  (Changed 2026-08-19 from "never by a control" — a control was the whole point of the change. Changed
  again 2026-08-20: the ban on a keyboard-accessory row is **lifted**, and the toolbar it forbade is
  what ships. The reason is the one that produced the control in the first place — `Aa` in the
  navigation bar put the commonest act in the app three steps away, at the opposite end of the screen
  from the writer's hands, and a capability nobody finds is a capability that does not exist. What the
  ban protected was never the *placement*; it was the vocabulary, and the vocabulary is unchanged.)
  The toolbar MUST stay contextual: it appears only while the **body** has the caret, shows only the
  microphone while reading, and is absent entirely while the title has the keyboard. Structure MUST
  NOT visually dominate writing, and the app MUST still read as a page. It offers exactly six structures —
  Paragraph / Heading / Subheading / Bulleted List / Numbered List / Checklist — plus the writing-help
  reference — three of them (Bulleted List, Numbered List, Checklist) as one-tap buttons and the rest
  behind `Aa`. Nothing else joins it. (`Normal` renamed to **Paragraph** 2026-08-19: the row is the writer's explicit way *out*
  of a list, the counterpart to Return on an empty item, and "Style → Paragraph" says that where
  "Style → Normal" read as a preference. Title-cased and `Bullet list` → **Bulleted List** 2026-08-20,
  to Apple's own wording for these rows.)
- **A menu label and a spoken phrase are allowed to differ, and MUST NOT be collapsed into one
  string** (added 2026-08-20). The Style menu says **Bulleted List**; the voice parser hears
  `bullet list`. A label is read at a glance and a phrase is said out loud, and forcing one string to
  serve both makes one of them wrong. The menu label MUST come from `BlockStyle.name` and the spoken
  form from `VoiceStructureParser.phrases`; every surface that shows either MUST read it from that
  source rather than repeating the literal, so the two can never drift by accident. Inline formatting (bold, italic, underline, colors,
  alignment, font size) MUST NOT join it: that is full rich text, which stays on the §7
  do-not-build list.
- Voice and typing are two input methods for the **same** note — not two note types.
- A voice transcript MUST become ordinary, editable text.
- **Voice is free in V1 and MUST NOT be gated behind a purchase.** There is no subscription, no
  credit balance, and no Pro tier — so there is also nothing to upsell, and no upgrade call to action
  may appear anywhere in the voice flow. (Locked 2026-08-21.)
- A single recording MUST NOT exceed **5 minutes**, and reaching the cap MUST finish and transcribe
  what was captured rather than discard it. (Changed 2026-08-21 from 10 minutes.)
- An attested installation receives **60 minutes of successful transcription per UTC calendar
  month** as a **soft** ceiling: a recording begun while under the ceiling MUST be allowed to finish
  completely, and only the *next* one is refused. Enforced by the relay, never by the client.
- **No recording may be spent discovering the ceiling.** The transcription that reaches the limit
  MUST still return its words, and MUST report the exhaustion on that same successful response so
  the app can refuse the *next* microphone tap before the recorder opens. A limit that announces
  itself only by rejecting an upload teaches the user where it was by taking a spoken thought from
  them. `429 monthly_voice_limit` stays as the fallback for stale or reinstalled clients.
- The monthly allowance MUST NOT become visible interface. No usage meter, progress bar, credit
  count, or Profile usage screen. A user learns the limit exists from Writing Help, the Support FAQ,
  or the one dialog shown when they reach it — nowhere else. The relay MUST NOT send the client a
  used, remaining, or total figure: a flag and a reset instant are all it may know, because a number
  the client holds is a number the interface eventually shows.
- Only a **successful transcript** consumes allowance. Cancelled, rejected, failed, and `no_speech`
  requests MUST NOT. See `docs/04-voice-transcription.md` §14.
- V1 voice target languages: English, Telugu, Hindi, Telugu+English, Hindi+English.
- Face ID / device authentication lock is **optional** and opt-in.
- App content MUST be obscured in the app switcher when privacy lock is enabled.
- Appearance is user-selectable in Profile → Settings → **Theme**: Light / Dark / Use device settings
  (default = system). Persisted across launches; applied via `preferredColorScheme` at the app root.
  (Added intentionally — the original V1 spec locked system-only. When the theme is "Use device
  settings", the app still follows iOS.)
- MUST use SF Symbols for system icons. No emoji-as-interface.
- SwiftUI native-first implementation; local storage via SwiftData.
- The transcription API key MUST NEVER ship inside the iOS application.

---

## 2. Voice & verbatim-capture contract

Source: `docs/04-voice-transcription.md` (whole file), `docs/01-product-requirements.md` §10, `docs/02-features.md` (Voice sections).

**The core contract:** _Spoken thought → faithful text representation of that spoken thought._

> ### Preserve the words. Format the speech.
>
> Punctuation and capitalization are how written language *represents* speech — supplying them is
> transcription, not editing. Changing **which words the speaker used** is editing, and is never
> allowed. (Changed 2026-08-18 from an over-literal "no changes whatsoever" reading; the forbidden
> list below is unchanged.)

**MUST be allowed** (readability formatting):

- capitalization
- sentence boundaries and full stops
- commas, question marks, and exclamation marks where clearly supported by the speech
- punctuation inferred naturally from delivery
- paragraph breaks where a meaningful pause or topic change is reliably detected
- minimal whitespace around an inserted transcript

The transcription path MUST NOT intentionally:

- translate speech
- summarize speech
- rewrite or paraphrase speech
- polish or "fix" grammar
- replace vocabulary with different words
- change tone or make sentences "more professional"
- remove slang because it sounds informal
- convert Telugu/Hindi to English by default
- collapse mixed-language speech into a single language
- invent/hallucinate content during silence
- replace the user's content with an AI-generated interpretation

Worked example (the boundary in one pair):

| | |
|---|---|
| **Spoken** | `Actually I don't know maybe we can go Saturday but if Ravi is coming then Sunday is probably better what do you think` |
| **Allowed** | `Actually, I don't know. Maybe we can go Saturday, but if Ravi is coming, then Sunday is probably better. What do you think?` |
| **Forbidden** | `Ravi and I should probably go on Sunday instead of Saturday.` |

Additional voice rules:

- MUST NOT run the transcript through a general LLM cleanup pass (e.g. "fix mistakes",
  "clean grammar", "make readable"). Punctuation MUST come from the transcription model itself,
  never from a second generative rewrite pass.
- Allowed deterministic cleanup is limited to **transport/UI artifacts only** — e.g. trimming an
  accidental trailing transport newline, or preventing double spaces at an insertion boundary.
- The **contract metric** is content WER (`contentWordErrorRate` — case- and punctuation-insensitive),
  not raw WER. Raw WER and punctuation error rate measure readability and inform the model/prompt
  choice; only content WER, script preservation, and unwanted translation gate a release.
- Writing-system goal: Telugu → Telugu script; Hindi → Devanagari; preserve natural English terms
  inside mixed speech where the model can do so reliably.
- Language hints are **benchmark-driven, not assumption-driven**. MUST NOT force a single language
  on every recording — code-switching is a core use case. Fall back to model language detection if
  explicit hints reduce quality for a test group.
- On any failure, MUST NOT invent replacement text. Offer explicit actions (Retry / Discard / Try Again).
- V1 requires network for transcription. When offline after recording: retain the protected temp
  audio for **explicit** retry only, tell the user a connection is required, and MUST NOT silently
  upload later without user intent.
- Recommended path (V1): record completed audio → send file → transcription model → insert final
  transcript. Do NOT build Realtime unless the product later needs live text.
- The transcription **model MUST be chosen from measured performance** on the consented corpus
  (`compareArms` in `Core/Voice/TranscriptionBenchmark.swift`), never because a model is newer or
  generically recommended. V1 ships `gpt-4o-transcribe` until a benchmark run says otherwise.
- A capture interrupted by a call or Siri MUST finish with the audio recorded so far rather than
  discard the user's words. **Leaving the editor mid-recording MUST do the same** — stop the recorder,
  finalize the file, upload, insert. (Corrected 2026-08-27. This bullet read "MUST cancel the capture
  and delete the temporary audio" long after `docs/04-voice-transcription.md` §6 reversed it on
  2026-08-19: deleting audio the user had already spoken was a data-loss bug, and Back was the one
  exit that still did it. `VoiceCaptureModel.finishOnLeave()` owns the corrected behavior. The one
  exception is a first recording whose transcription disclosure has not been accepted — that audio may
  not be sent and may not be kept, so leaving still discards it.)
- Abandoned temporary recordings (crash / force-quit) MUST be swept at launch.

### Cursor insertion contract

- Capture the intended insertion selection/location **before** recording starts.
- When there is **no active cursor** (an existing note open for reading, keyboard hidden), the
  transcript MUST be appended to the end of the note — never dropped, never given its own object.
- Insert at the saved cursor anchor (replacing selected text only if that is explicitly intended);
  preserve surrounding content.
- The `TranscriptionService` MUST NEVER mutate the note directly — the editor owns insertion.
- May insert minimal boundary whitespace/newlines to avoid joining words; MUST NOT otherwise
  rewrite transcript content.

### Structure the words (roadmap — NOT in shipped V1)

The long-term goal is that anything creatable by typing is also creatable by speaking, on the **same
document model** — never a separate voice-only document system. When structured voice ships, these
contracts apply. They are roadmap: MUST NOT be marketed until shipped (see §7).

- "Preserve the words. Format the speech." extends to **"Structure the words."** Voice may *structure*
  the user's words when they explicitly ask; it MUST NEVER *replace* them. Everything in the forbidden
  list above (translate / summarize / rewrite / paraphrase / grammar-fix / re-vocabulary) stays forbidden.
- The command vocabulary is **small, fixed, and deterministic**: nine *actions* — `new paragraph`,
  `new line`, `heading`, `subheading`, `bullet list`, `numbered list`, `checklist`, `next item`,
  `end list`. MUST NOT grow into dozens of commands, and MUST NOT use a generative model to *infer*
  what formatting the user "probably" wanted.
- Each action MAY accept a **small, closed, listed set of spellings** (added 2026-08-19): `start bullet
  list` / `bulleted list`, `start numbered list`, `start checklist`, `new item`, `stop list` /
  `normal paragraph`. This multiplies *spellings*, never actions — speech is not a keyboard, and a
  writer who says "start bullet list" meant the command, not the words. Every alias MUST clear exactly
  the same boundary tests as the canonical wording, and the set MUST stay enumerated in
  `VoiceStructureParser.phrases`. Help teaches **one** phrasing per action; the aliases are accepted,
  not advertised.
- **Leaving a structure is an action, not a newline.** `end list` (and its spellings) MUST do what
  Return on an empty item does: if the current item holds nothing but its marker, the marker goes and
  the line becomes a paragraph. It MUST NOT strand an empty marker behind the writer.
- **Safety rule:** when it is uncertain whether a phrase is a command or literal content, **preserve the
  spoken words** and take no action. Recognize a command only when it appears as a clearly isolated phrase,
  at a sentence/utterance boundary, using exact supported wording, in a context where the action is valid.
- **Punctuation belongs to the command.** A recognized command absorbs the whole punctuation run the
  model transcribed after it (`new paragraph...`, `heading…`, `checklist!`). Stray leftover punctuation
  MUST NOT land in the note. This never widens *recognition*: a phrase that was not a command stays words.
- **Boundary:** *Touch chooses where. Voice chooses what.* No hands-free navigation, selection, cursor
  movement, or deletion commands in this stage (e.g. "go to paragraph three", "delete last two paragraphs").
- **Architecture:** faithful transcription first → a conservative command parser → document actions applied
  by the editor. The transcription service MUST NOT mutate the document. Typing and voice MUST converge on
  one shared document-action layer rather than two independent formatting systems.
- Commands may launch in **English** first if that is the cleanest implementation; Telugu/Hindi command
  equivalents are evaluated separately and MUST NOT compromise code-switch transcription quality.

### Voice V2 (direction locked 2026-08-27 — partly built)

Full direction: `docs/10-voice-v2.md`. The scope is settled. **Built so far:** Home Quick Voice
(Phase 1); the shared recording state machine, pause/resume, recorded-duration accounting, and the
five-minute cap summed across pauses (Phase 2A, 2026-08-28); and retained recordings with their
24-hour expiry, Retry / Delete Recording, audio-route and Bluetooth handling, and background and
interruption durability (Phase 2B, 2026-08-28). **Not built:** voice into table cells, and the App
Intent. None of it may be marketed before it ships (§7). The contracts below **bind** — they are not
conditional on a later decision.

**Navigation is not deletion, and neither is a terminated process** (decided 2026-08-28). A retained
recording outlives the screen it failed on: leaving the note keeps it, and so does the app being
closed. On the next launch — and on the next return to Home — a valid retained recording younger than
24 hours is offered back **once**, on **one** surface, with the same two controls and nothing else:

```text
We saved a recording that couldn't be transcribed.

    Retry            Delete Recording
```

That surface is the boundary. No recordings list, no playback, no file name or date on screen, no
history, no rename, no export, no background upload — any of those is the excluded `audio archive` (§7)
arriving through the back door. What is persisted is the minimum that can identify one file and keep
its clock honest: the recording's **name**, its `retainedAt`, and which surface it came from
(`RetainedRecordingStoring`). The name rather than the path, because the temporary directory moves
between installs.

This covers the upload too. Leaving a note while the transcription is still **in flight** retains the
recording rather than cancelling and deleting it: the user finished speaking and committed the audio,
and navigating away is not a decision about it. The order is fixed — claim the recording, *then*
abandon the attempt — and a late answer from an abandoned attempt MUST NOT insert into the note that
was left, create a note, delete the retained audio, or clear the recovery record. Each attempt carries
an identity (`VoiceCaptureModel.isCurrentAttempt`) because cancellation is cooperative and a request
that already reached the relay answers whether or not anybody is listening. Retry is always a new
attempt.

A recording captured **inside a note** keeps its captured insertion point only while that editing
session is alive. Once the session is gone the caret it was aimed at is meaningless — the note may have
been edited since — so a recovered transcript becomes a **new ordinary note**, and the recovery surface
says so before the retry rather than after it. Editor internals are never persisted.

- **The recording timer measures recorded audio, never wall-clock time.** A pause does not spend the
  five-minute cap; the cap applies to the summed recorded duration across any number of pauses, and the
  relay stays the authority on the file it is given (`docs/04-voice-transcription.md` §7). `recording`
  and `paused` MUST be distinct states rather than one state and an `isPaused` flag — the flag version
  is how a paused recorder keeps counting, and a capture cut off by a limit it never spent loses the
  thought it was taking. Pause/resume MUST leave **one continuous recording**, never segments to
  reassemble.

- **A voice-created note is an ordinary note.** No voice section, no voice folder, no microphone badge
  on a row. Nothing in the model, timeline, search, or export may record that a note's words were
  spoken — the moment one does, voice is a note *type* and As Told has a second document system.
- **Quick Capture is transient until it earns a note.** A capture started from Home MUST NOT create a
  `Note` when the microphone opens; a note exists only once a non-empty transcript does. Cancel,
  denial, no-speech, declined consent, and transcription failure leave **no note** behind. A retryable
  failure leaves one thing and one thing only: the recording itself, retained under the rule above so
  the user can still turn it into text.
- **One Quick Capture implementation, several entry points** (Home, in-note, App Intent). A second
  capture flow behind the Action Button is how the two drift. An App Intent MUST NOT bypass the app
  lock (§3).
- **Voice MUST NEVER summon a keyboard that was not already visible.** Someone who chose to speak has
  made a choice with their hands; answering it with a keyboard overrides it.
- **A rejected attestation is not a failed transcription** (added 2026-08-31, after production
  evidence). App Attest is the app's own setup, and the user has no part in it. A `401` means our
  registration is stale — the relay forgot the key, or the install changed underneath it — and the
  relay rejects it *before* it reads a byte of audio, so nothing has been attempted. The client MUST
  repair the registration and complete the request the user asked for, **once**; a second rejection
  is a real failure and stands. It MUST NOT be shown as "Couldn't transcribe that recording", and the
  user MUST NOT be the mechanism by which the app re-authenticates itself.
  This does **not** loosen the rule above it: a transcription that actually failed — audio the relay
  took, tried, and could not turn into words — is still never retried automatically, and `401` is the
  only status that gets a second attempt.
- **A rejected attestation MUST say why in the relay log** (added 2026-08-31). The verifier already
  distinguishes a missing assertion, an expired challenge, an unknown key, and a bad signature; all
  four used to be discarded at the route boundary into one opaque `attestation_failed`, which left the
  failure most likely to be our own bug the one nobody could diagnose. Metadata only: the reason, and
  whether a key id was present — **never which**, because a key id identifies an install (§3).

- **The capture's state MUST match the recorder's** (added 2026-08-30, after audit). `AVAudioRecorder`
  MUST have a delegate, and an unexpected finish or an encode error MUST reach the capture. A capture
  MUST NOT remain `recording` — with a timer counting and a waveform drawn — once the recorder
  underneath it has stopped. The recorded-duration clock stops when the capture actually terminates,
  not when the app notices.
- **An unexpected stop MUST NOT look like a completed recording** (added 2026-08-30). A recorder that
  stops on its own — an encoder failure, a finish nobody asked for — keeps every second it captured,
  exactly as an interruption does; what it MUST NOT do is transcribe and hand back a note as though
  the user had ended it. The capture stops at `stoppedUnexpectedly`, says so, and offers the two
  controls held audio always has: send it, or delete it. This is `docs/10-voice-v2.md` §14's *say what
  happened* applied to the one ending that had no way to say anything. A call or Siri is unchanged and
  still finishes and transcribes: the user knows a call arrived, and nobody is told a recorder failed.
- **Finalization is a step, not a label** (added 2026-08-30). No upload begins until the recorder has
  confirmed it stopped and the container it wrote has been **measured** on-device. A file with no
  usable duration is refused locally rather than uploaded — the relay measures the same way and would
  refuse it anyway. `Phase.finishing` is where this happens, and it is the only way out of a capture.
- **A transient route observation is not proof the microphone is gone** (corrected 2026-08-30). Route
  change notifications are delivered *while the route is changing*, so `currentRoute.inputs` is
  momentarily empty during transitions a recording survives intact. An empty read MUST be escalated to
  a settled check of the session, never acted on as an ending. Unchanged: an input the system says has
  gone (`.oldDeviceUnavailable`, `.noSuitableRouteForCategory`) still finishes safely, a newly
  available device still never switches the microphone mid-thought, and nothing ever auto-resumes.

- **A finished recording is not casually lost.** After a retryable transcription failure the audio is
  retained on-device for **explicit** retry, for **24 hours** (`VoiceLimits.retryLifetime`, a named
  constant beside the other voice limits, never a number in the view layer). Which failures qualify is
  one central classification, `TranscriptionError.isRetryableVoiceFailure`, so the two capture surfaces
  cannot disagree about whether a user's words still exist. The launch sweep deletes anything older (§3). Never a background queue, never a silent later upload, and deleted immediately on
  success. `Delete Recording` is the only management affordance — a list, playback, or export is the
  excluded `audio archive` arriving through the back door (§7).
- **"One retry" means one affordance, not one attempt.** One retained recording, one Retry control,
  one Delete control. Retry MAY be tapped again after each further retryable failure until **success**,
  **explicit deletion**, or the **24-hour expiry** ends it. A single permitted attempt would reintroduce
  the data loss this rule exists to prevent, one attempt later: a flaky connection is the normal reason
  a retry is needed, and the second attempt is the one most likely to work.
- **The vocabulary does not grow.** Voice V2 adds no structure commands to the nine that shipped.
- **The free voice interaction MUST NOT be made worse to create a Pro upsell.** Pro voice is capacity
  and nothing else. Pause/resume and interruption recovery are **Free**, which reclassifies them from
  `docs/09-v2-roadmap.md` §2.4.

**Refused 2026-08-27 — out of Voice V2 entirely, and no amendment is being drafted for either:**

- **Self-correction resolution** ("meeting at six, actually seven" → "meeting at seven"). **Not built.**
  It deletes words the speaker said, which the forbidden list above prohibits and which §11 of the
  voice spec puts outside the transport-artifact carve-out. Its trigger words are ordinary content
  words, its failure mode is *silent* deletion with no error and no trace, and it degrades worst in
  exactly the code-switched speech As Told exists to get right. As Told stores "Meeting at six —
  actually seven", and that is a correct outcome. Reopening it requires real user demand and a fresh
  rule change whose bar is a measured **unwanted-deletion rate** per language group — content WER
  measures wrong words, not missing ones. That work is not scheduled.
- **The voice dictionary — the local list UI included, not only the server hints.** **Not built.** A
  dictionary earns its place only by being sent as a transcription hint (a new category of personal
  data leaving the device, which §3 does not permit) or by substituting words after transcription (a
  second word-changing system, which the contract above forbids). Without one of those it is a settings
  screen that changes nothing while letting people believe it does. Deferred to a separable experiment
  on the benchmark corpus; if that says hints help, the feature is designed deliberately with an
  amendment to §3 naming what is sent and disclosure to the user (`docs/10-voice-v2.md` §19).

---

## 3. Privacy & security rules

Source: `docs/01-product-requirements.md` §11, §13, `docs/04-voice-transcription.md` §5, §13–14, `docs/05-architecture.md` §16–19, §22, `docs/06-tech-stack.md` §10–11, §19.

### Data ownership

- The note database MUST live in the app container on device (local-first). No cloud note DB in V1.
- Before the **first** recording ever leaves the device, the app MUST show a one-time disclosure
  naming the third party that transcribes it and MUST NOT upload until the user accepts. Microphone
  permission is permission to *record*, never permission to *send* (App Review 5.1.2(i);
  `docs/04-voice-transcription.md` §6). Declining MUST delete the recording and send nothing.
- The transcription service receives **only** the audio the user explicitly chose to transcribe,
  plus static instructions, allowed language hints, and non-content metadata.
- MUST NOT send the full existing note to the transcription model as context.

### Backend MUST NOT persist

- raw audio
- transcript text
- note title
- note body
- search terms

The relay's durable storage is limited to two things, both anonymous and both content-free: the App
Attest key registry (key id, public key, assertion counter) and the monthly voice-usage counter
(hashed install id, UTC month, seconds). Anything beyond those two MUST be justified against this
list before it is added, and neither may be extended to carry note-derived data.

### Logging

- Server logs may contain **metadata only**: request ID, route, status code, latency, model id,
  audio byte size, approximate duration, coarse error category.
- MUST NEVER log audio, transcript, title, body, or search queries.
- Client logs (OSLog/MetricKit) MUST NOT contain note or transcript payloads.
- Crash logs MUST contain no note text.

### API key & endpoint

- The standard OpenAI API key MUST stay server-side. MUST NEVER be placed in Info.plist, app source,
  client-readable remote config, the Keychain as a bundled secret, or an obfuscated binary. **Non-negotiable.**
- HTTPS only.
- The transcription endpoint MUST be protected against abuse: App Attest validation, per-attested-install
  rate limiting, IP anomaly limits (secondary), request size limit, duration limit, a monthly
  per-install fair-use allowance, MIME validation, timeout, and a server-side model allowlist. An
  anonymous public endpoint is NOT sufficient.
- The per-recording cap, the per-minute rate limit, and the monthly allowance protect three different
  things and MUST NOT be collapsed into one control or traded off against each other. Raising or
  removing any one of them MUST NOT be justified by the existence of the other two.
- App Attest is anti-abuse protection, **not** user authentication. Development builds need a controlled
  bypass; a generic `X-Debug-Bypass` MUST NOT work in production.
- A production relay MUST NOT boot with attestation off. The only way past that is
  `APP_ATTEST_ALLOW_UNPROTECTED=true`, which exists for the pre-launch staging deploy and MUST NOT be
  set on any build real users can reach.

### App lock & app switcher

- App lock is opt-in; authenticate at enable time and on return to active.
- When lock is enabled and the app leaves active state, note content MUST be covered before the system
  snapshot — readable text MUST NOT remain in the app-switcher snapshot or behind the lock UI.
- App lock is an access gate, NOT a claim of end-to-end encryption. MUST NOT market beyond the threat model.

### Temporary audio

- Lives only in an app-controlled temporary/application-support location, with iOS file protection and
  randomized names. MUST NEVER go to Photos or shared Documents.
- MUST be deleted on Cancel, on successful transcription, and on Discard; abandoned files MUST be cleaned
  on launch beyond the allowed retry lifetime. The launch sweep spares exactly one file: the single
  recording retained after a retryable failure, and only while it is inside `VoiceLimits.retryLifetime`
  (§2). Everything else in the temporary directory is abandoned by definition and goes.

### Analytics

- Prefer Apple platform diagnostics (App Store Connect analytics, MetricKit, OSLog).
- MUST NOT install any third-party session-replay SDK capable of observing typed note content.
- Any future custom analytics MUST NEVER include note text, transcript text, audio, or search queries.

---

## 4. UI / UX rules

Source: `docs/03-design-system.md` (whole file, incl. §0 Visual reference),
`docs/01-product-requirements.md` §8–9, §12.

> **Canonical visual target:** `docs/design-reference/screens-overview.png`. Match it for look and
> feel; where pixels and prose disagree on behavior, the specs and this file win.

### Brand mark & wordmark

- The brand is a minimal **feather/quill mark** + a **serif wordmark** logotype, used **only** on
  Splash, Welcome, and Lock screens.
- This is a **logotype asset**, not a UI font. MUST NOT set a serif as a UI text font — all UI text
  stays system San Francisco + Dynamic Type (see §6 tech rules and §4 tokens below). This does not
  weaken the "no custom font in V1" rule.

### Core UX rules (non-negotiable)

1. The note is more important than the interface.
2. Never require Save.
3. Never require organization before capture.
4. Never ask a permission before the user invokes the feature.
5. Prefer inline interactions over extra screens.
6. Prefer native iOS controls when they already solve the interaction.
7. Voice and typing are the same note.
8. Deletion is reversible for a short period (Undo).
9. No user-facing pagination.
10. No interface copy that judges, encourages, gamifies, or diagnoses the user.
11. No time-of-day greeting.
12. Do not show creation time on normal Home rows.
13. Follow the system Light/Dark setting by default. The Theme picker (Light / Dark / Use device
    settings, defaulting to device settings) is an intentional, kept setting — see §1 and
    `docs/03-design-system.md` §15. Do NOT add further colour themes.

### Home

- Header shows: subtle current date, the first period heading, and the Profile / Calendar / New Note
  / Quick Voice actions. (Amended 2026-08-30: the prominent largeTitle `Today` **anchor is gone**.
  `Today` is now a period heading, and drawing it as both anchor and heading rendered it twice — a
  duplicated heading is a bug, and VoiceOver reads it out loud. The current date rides above the
  first heading rather than occupying a band of its own.)
- MUST NOT show greeting, weather, current time, quote, writing prompt, streak, statistics, the app's
  own name, or a count of the library.
- The four header action glyphs — Profile, Calendar, New Note, Quick Voice — each carry their own
  muted accent tint, and Quick Voice carries its own rather than sharing New Note's. (Restored
  2026-08-31, after a day drawn in `textPrimary`. **The monochrome rule below is about content and
  surfaces, not about navigation**: four identically-inked glyphs in one corner have to be read
  before they can be told apart, and writing and speaking are peers rather than one being the
  other's second button. Home's grounds, note surfaces, text, and dividers stay neutral.)

### Calendar

- The calendar page uses **one** accent, `calendarAccent` — the sage its glyph wears in Home's header
  — for every piece of interaction state: month chevrons, the selected day's fill, today's ring, and
  the density dots. Colour here carries **state**; it does not decorate. (Added 2026-08-31.)
- Today's marker and the selected marker MUST differ in **shape** (ring vs. filled), not only in
  colour: both are true on the day the screen opens, and a reader must be able to see both.
- `calendarAccent` is **not** `iconCalendar`. The glyph's sage is 4.02:1 against white, which is fine
  for a symbol and below the 4.5:1 floor the moment a day *number* is drawn on it. Light is the same
  hue 12 % darker (`#457968`), measured 5.01:1 on screen against `onAccent`; Dark is the glyph's own
  `#86BCA9`, measured 8.80:1. Any future change to either MUST be re-measured, not eyeballed.
- Row: if a title exists → title (one line, ~17 pt semibold, `textPrimary`) over a **two**-line
  flattened body excerpt (~15 pt regular, `textSecondary`); if not → **no title line**, and the
  excerpt alone at body size (~17 pt regular, `textSecondary`), two lines. Never generate `Untitled`.
  (Amended 2026-08-30 to a one-line preview for density, and amended again 2026-08-31 to two: one
  line turned a titleless note into a lone sentence that read as a headline. Rows are no longer a
  uniform height — a titled note has genuinely more to show, and forcing both shapes to match is
  what cost the excerpt its second line. Measured at default type: a titled row with a two-line
  excerpt is **85–87 pt**, a titleless one **67 pt**.)
- A row's preview is **flattened**: the lines the reader would have seen, joined onto one line. No
  marker, fence, or table pipe may reach it (see the structure-marker rule below).
- **No card per _note_.** A note MUST NOT be its own floating rounded rectangle. One rounded surface
  **per period**, holding that period's rows separated by hairline dividers, is what Home draws.
  (Amended 2026-08-30, replacing "prefer `VStack` rhythm over rounded rectangles". What that rule
  protected was a screen of per-note cards, and it still forbids exactly that; a single grouped
  surface is the opposite — it is what lets the rows be dense.)
- Home MUST NOT show a note's creation **time** on a row. This did not change with the grouped
  redesign, and was deliberately re-affirmed on 2026-08-30 when a `9:41 PM ·` preview prefix was
  proposed and dropped.
- Must remain navigable and premium with 0, 1, many-today, many-days, long/absent titles, long
  bodies, and large Dynamic Type. Verified at 500–1,000+ notes.

### Editor

- Required elements: Back, **the note's date**, **Share**, Style menu, optional title field, body text
  area, mic control — and nothing else. The Style menu is contextual: present only while the body has
  the caret, gone while reading and while the title is being edited (styling a title means nothing).
- **The header is Back · date · Share (amended 2026-08-26).** The date **moved into the navigation
  bar**, centred, and Share joined it on the right. Three things this changes, each deliberate:
  - **It supersedes the 2026-08-20 scrolling-date decision** for the date only. That decision exists
    because a header pinned *inside* the page left a long note sliding underneath it, clipped mid-line.
    A navigation bar is not that: it reserves its own height and the page begins below it, so the
    clipping cannot come back through it. **The title stays in the scroll** for the original reason,
    and always will.
  - **It supersedes "prominent timestamp"** in the forbidden list below, which was written when the
    only way to show a date was to put it over the writing width. A centred, tertiary, one-line date in
    the navigation bar is the note saying when it was last written to, and it is what every note app on
    the platform does.
  - **The date is drawn exactly once.** It is not in the page and in the bar; a duplicated timestamp
    reads as a bug and VoiceOver says it twice.
  - It is `updatedAt`, in the reader's locale, to the minute. Not `createdAt` — the timeline already
    says when a note was born, and what a reader wants from the note in front of them is when it last
    changed. Not a hand-written `MMMM d, yyyy` pattern, which is only correct in English.
  - **Still no overflow menu.** Share is one button because it is one verb. The moment it becomes `…`,
    duplicate / word count / pin have a door (§7).
- The editor has **no overflow menu**. Deleting a note happens on the timeline, by swiping it —
  one place, one gesture, still soft-delete + Undo with no confirmation dialog. (Changed 2026-08-19;
  the editor previously held a `Delete Note` overflow. An overflow in the editor is how share /
  export / duplicate / word count / pin arrive, and those are all on the do-not-build list (§7) —
  removing the menu removes the door.)
- Forbidden default UI: Save button, `Done`, overflow menu, attachment row, AI button, word count,
  and any bar that occupies the writing width or sits above the note's text. (`prominent timestamp`
  left this list on 2026-08-26 — see the header rule above. The navigation bar is not "a bar that
  occupies the writing width": it is the bar the platform already draws, and the note begins beneath
  it.)
  - **The writing toolbar is not that bar** (amended 2026-08-20; this list previously forbade a
    "formatting bar", a "standalone checklist button", and named `H1 H2 • 1. ☑` as the forbidden
    keyboard-accessory row). What ships is a floating island below the note, above the keyboard,
    holding `Aa` · `•` · `1.` · `☑` · microphone — the six structures the editor already has, plus
    voice. It takes no width from the page, it is never present while reading or while the title has
    the caret, and it adds not one capability the app did not already ship.
  - What the list still forbids is **inline** formatting reaching this bar or any other: bold, italic,
    underline, colors, alignment, font size (§7). A bar with room on it is not an argument for them.
- Title placeholder `Title`; body placeholder `Start writing…` and nothing else. No visible
  box/border on either. (The empty note carried a marker cheat-sheet until 2026-08-19; it went with
  the arrival of the Style menu — teaching syntax before the first word was the price of having no
  control, and that price is no longer owed.)
- Editing an old note MUST NOT move it to Today — timeline sorts by creation date, not last edit.
- Undo MUST cover structural editing exactly as it covers typing: **one user action is one undo step**
  — ticking a checkbox, Return continuing a list, Backspace demoting a line, a voice transcript landing —
  restoring precisely the text, structure styling, and caret that were there before, with redo available.
  A document mutation MUST NOT be applied by assigning the text view's whole string: that bypasses undo
  registration and leaves the stack describing text that no longer exists.
- Structure markers (`# `, `- `, `- [ ] `, …) are an internal encoding and MUST NOT be visible anywhere:
  not in the editor, not in Home/search previews, not to VoiceOver, and not in anything copied out of the
  app. **The caret MUST NOT be allowed to sit in front of a hidden marker either** (added 2026-08-21):
  a marker is not a place, and a caret parked at a line start let the next keystroke insert ahead of it,
  which put the marker mid-line where it stopped being hidden and became words. A table's pipe source is
  covered by the same rule on every surface that shows a note *as text* — Home, search, VoiceOver — and
  by the documented exception on the pasteboard, where copy still yields the source.
- **VoiceOver MUST be told what a marker draws, not left with the words alone** (added 2026-08-21). A
  ticked and an unticked box that read identically are state carried by a mark and nothing else, which
  the accessibility rules in §4 forbid. Copy/cut MUST give other apps the page as it reads (`• Eggs`, `☐ Call Ravi`); the raw source may
  travel only in a **private** pasteboard representation, so an As Told → As Told paste keeps its structure.
- **Paste MUST NOT rewrite the pasted words, and MUST NOT infer structure from a clipboard that does not
  state any.** Structure may be *translated* from what the clipboard states outright — an HTML heading
  becomes a Heading, a list item becomes a list item, a checkbox becomes a Checklist item — and never
  deduced: a short line is not a title, and large bold type is not a heading. External plain text MUST be
  inserted character-for-character. Styling As Told does not have (bold, italic) loses the styling
  and keeps every character of its text. **`links` left this list on 2026-08-23** (V2 Phase 1): a
  destination is not an appearance, and a stated hyperlink now keeps both its words and its address —
  see the links exception in §7. A destination As Told will not open (`mailto:`, a relative path,
  `javascript:`) still keeps only its words. See `docs/02-features.md` (Milestone A).
  - **What counts as *stated* (clarified 2026-08-20; the rule above is unchanged).** A format the
    clipboard names — `public.html`, `public.rtf`, a declared Markdown type — states its own structure,
    and MAY be translated. `public.plain-text` names no format, states no structure, and MUST NOT be read
    for any, however much of it resembles Markdown. Inside a list the source itself declared, a leading
    checkbox glyph (`☐`, `☑`) is that item's marker, the same way `•` is, and MAY be read as the Checklist
    item it draws; the identical glyph in a paragraph, in a heading, or anywhere in plain text is a
    character the writer typed and MUST stay one. A list item MUST keep its structure through whatever
    element wraps its words (`<li><p>…</p></li>`).
  - **Amendment — high-confidence code detection (2026-08-24, decided by the product owner).** The rule
    above now reads: *never infer document structure from plain prose, **except high-confidence
    programming/code detection on paste***. Plain text that a detector is **certain** is code MAY be
    fenced automatically on a normal paste, so obvious Python/SQL/JavaScript/Swift/JSON/Bash/YAML arrives
    as the code card it is. This is the **only** inference from prose anywhere in As Told, and it is
    bounded:
    - It MUST run **only** on `public.plain-text`, and only after every stated flavor has declined. A
      clipboard that states structure is still translated, never re-read.
    - It MUST name only a language `CodeHighlighting` can colour, so a detected block always arrives with
      a real label and real syntax colour. A language that cannot be coloured MUST NOT be detected.
    - It MUST require a **decisive** signature (one that essentially cannot occur in a sentence) or at
      least three supporting ones, and a prose guard MUST overrule any score. A single line MUST NOT be
      detected unless its signature is decisive.
    - When confidence is short of certain, the text stays prose and **Paste as Code** remains the
      writer's manual override. Detection MUST NOT alter one character of the clipboard: it adds fences
      and nothing else.
    - The asymmetry is the design and MUST be preserved: code left as prose costs one tap; prose turned
      into a code card is the note being rewritten. When in doubt, do nothing.
    See `Core/Editor/CodeDetection.swift` and `Tests/YourlyTests/CodeDetectionTests.swift`, whose
    negative corpus is deliberately larger than its positive one.
  - **Accepted limitation (V1).** Because the canonical source syntax recognizes line-leading markers
    (`# `, `- `, `1. `, `- [ ] `), a pasted line that begins with one renders as that structure. The
    characters are unchanged and nothing else is inferred — the note reads as it was pasted, in the one
    respect the storage format cannot tell "typed as a marker" from "pasted as text". This applies equally
    inside preserved literal text — a `<pre>` block, a fenced Markdown block. Fixing it would mean escaping
    or per-line metadata in `body`, which is a storage redesign and MUST NOT be attempted for V1; inventing
    zero-width characters or invisible metadata to beat the renderer is not a smaller version of it.

**Tables — a table stays a table (amended 2026-08-24, Item 4).** The rule was "a table being edited is
text being edited", and its `| pipes |` and `| --- |` rule came back on screen the moment the caret
entered. That is storage, and a reader MUST never see it. Now:
- a table is **always** drawn as its grid — reading, typing elsewhere in the note, or editing the table
  itself. It MUST NOT flip to pipe rows from where the caret is.
- **a cell is edited in place, in the grid.** Tap a cell to edit it; tap another to commit and move;
  **Return** commits and moves to the next cell (A1 → B1 → C1 → A2); hardware **Tab**/**Shift-Tab** walk
  the same order; a tap outside a cell commits and leaves. Past the last cell, editing ends — a table is
  not a loop.
- the header rule is never addressable. Navigation walks the table's `rows`, which does not contain it.
- a cell is **one line**: a newline in committed text becomes a space, and a typed `|` travels escaped.
  Multiline cells are out of scope (§7).
- the card reports *which* cell changed and to what; the editor turns that into one ordinary,
  **undoable** `TextEdit`. `body` stays canonical pipe rows — the table is still stored as text (§5).
- a table too wide or too tall to lay out keeps its existing **preview** card and its reader. Preview
  cards are not editable in place, and their touches still belong to the page.
- **Still forbidden (§7 unchanged):** row/column insertion UI, drag resizing, sorting, formulas, merged
  cells, multiline cells, or anything else that makes this a spreadsheet.
- **Known gap for this pass:** with no source on screen there is no way to *add* a row from the editor.
  Row/column insertion was deliberately excluded here and MUST be designed before a table can be grown
  in place.

**Reading vs editing (one screen, no mode toggle):**

- A **new** note opens ready to capture: the body takes focus and the keyboard appears.
- An **existing** note opens for **reading**: nothing becomes first responder and the keyboard MUST
  NOT appear. Tapping the title or body starts editing at the tapped location.
- MUST NOT add an explicit `Read Mode` / `Edit Mode` toggle.
- The keyboard MUST be dismissable natively — interactive dismissal while scrolling, and navigating
  Back. MUST NOT add a large custom "Hide Keyboard" control.
- Because autosave is the only save, a trailing `Done` MUST NOT duplicate Back. It may exist only as
  the standard keyboard-dismissal affordance, shown only while a field holds the keyboard.

### Autosave

- Debounce active typing (~300–600 ms, reference 400 ms), flush on navigation away, flush on app
  background/inactive, flush after successful voice insertion. Never require user confirmation.

### Empty drafts

- On exit, if normalized title is empty AND body is empty/whitespace AND no transcription is pending →
  remove the draft. Do NOT clean user spacing inside a non-empty body.
- **A temporary scene transition MUST NEVER invalidate a draft an open editor still owns.**
  Backgrounding, resigning active, a permission alert, or any other interruption may *save* the
  current state — including an empty draft — but MUST NOT discard it. Discarding a draft mid-session
  used to delete it and commit the deletion, and a committed SwiftData deletion cannot be undone by
  re-inserting the same model: everything the user typed or spoke afterwards was then lost silently
  while the editor went on displaying it.
- Removing an abandoned empty draft belongs to exactly two places: **`finish()`**, when the user
  actually leaves the editor, and **`purgeEmptyDrafts()`** at the next launch, for one stranded by a
  termination. An empty draft briefly reaching disk is the accepted cost — cleanup is a housekeeping
  promise, and never losing content the user created is a correctness one.
- **Persistence and presentation are separate questions.** An effectively empty note may exist in the
  store while an editor owns it; it MUST NEVER be a user-visible row or mark — not on Home, not in
  Search, not in the calendar's day list or its dots. Every place that turns notes into rows goes
  through the shared `userVisibleNotes` / `Note.isUserVisible` rule, which is defined in terms of the
  editor's own `isEmptyDraft` so the timeline and the editor can never disagree about what counts as
  a note. Home used to render the draft as a zero-height row and its separator survived as a stray
  line under `Today` (2026-08-20). Remove the invisible row; do NOT hide legitimate separators.

### Navigation

- No tab bar in V1 — not enough top-level destinations. Model: Welcome (first launch) → Home →
  {Editor → Voice, Search, Calendar → Editor, Settings → App Lock}.
  (Calendar was specified as a sheet; it ships as a navigation push inside Home's stack, which
  gives it the system back button and one obvious way out. Implementation is the source of truth
  here — changed 2026-08-19. See `docs/03-design-system.md` §4.6.)
- A note opened from the calendar MUST return to the calendar, with the same day still selected.
  Back always undoes the step the user took; it MUST NOT reroute anyone to Home.

### Design direction — "Quiet Editorial"

Avoid: SaaS dashboard aesthetics, excessive cards, generic glassmorphism, bright gradients, AI sparkle
icons, emoji controls, heavy shadows, colorful category systems, oversized floating controls,
decorative animation that slows capture.

### Design tokens (use semantic tokens, never scattered literals)

- Colors via semantic tokens (`Color.ds.canvas`, `Color.ds.textPrimary`, …) or adaptive Asset Catalog /
  native system colors. MUST NOT scatter `Color(hex:)` or `gray500` across views.
- Reference palette (light / dark), **neutralised 2026-08-30**: `canvas` `#FFFFFF`/`#000000`,
  `groupedCanvas` `#F2F2F7`/`#000000`, `surfaceElevated` `#FFFFFF`/`#1C1C1E`,
  `separator` `#3C3C43` @29% / `#545458` @65%, `textPrimary` `#1C1C1E`/`#FFFFFF`,
  `textSecondary` `#5B5B61`/`#ADADB4`, `textTertiary` `#77777D`/`#909097`,
  `accent` `#314D63`/`#8AA9BE`, `onAccent` `#FFFFFF`/`#101112` (text drawn *on* an accent fill — not a
  fixed white, because the dark accent is light), `destructive` = iOS system red.
  - The **warm** canvas (`#F8F7F3`) and the cream dark `textPrimary` (`#F3F2EE`) are **gone**. No
    brand colour sits on a content surface: the feather mark carries the identity, and a tint behind
    the writing was competing with it.
  - `canvas` and `groupedCanvas` are two grounds because a page of writing and a grouped list want
    opposite things — nothing between the words and the screen, versus something for the row
    surfaces to be islands against. One token could not be both.
  - `accent` and the **four** header icon tints (`iconProfile`, `iconCalendar`, `iconCompose`,
    `iconVoice`) are **unchanged**: they are controls, not content. Neutralising the palette
    neutralised *content surfaces*; it never meant removing the colour that tells one control from
    another. `iconVoice` (muted lavender, `#6B5E93` / `#A99BD1`) was added 2026-08-31 so Quick Voice
    stops borrowing New Note's slate blue.
- Typography: system San Francisco + Dynamic Type-backed semantic styles. **No custom font in V1.**
  Editor line height ~1.35–1.45×.
- Spacing: 4-pt foundation (4/8/12/16/20/24/32/40/48/64). Default horizontal margin 20 pt (Home),
  20–24 pt (Editor).
- Radius: 8/12/18/24/pill — only where controls/sheets need shape. Do NOT wrap every note in a large
  radius; the grouped period surface on Home is one radius around **many** notes, which is the
  distinction that rule was drawing (amended 2026-08-30).
- Icons: SF Symbols only. No emoji, no Font Awesome, no mixed icon libraries.
- Materials / Liquid Glass: use for **controls and navigation** (New Note, mic, recording surface,
  sheet/nav controls) — NOT for content. The content plane stays calm and opaque. Never put the whole
  editor or every note on glass.
- Shadows: default none; if a floating control needs one, extremely subtle and system-like.
- Motion: prefer SwiftUI transitions/springs over hardcoded web-style timing. Respect Reduce Motion.
- Haptics: selective (mic start/stop, delete, error). Never on every normal tap.

### Accessibility (required from first implementation)

- All text scales with Dynamic Type; controls MUST NOT clip or overlap at accessibility sizes.
- Every icon action has a clear VoiceOver label (`New note`, `Start recording`, `Open calendar`, …).
- A control VoiceOver can **describe** must be one it can **operate**. Where the only way in is a
  touch on a region of the screen — a checkbox in the body of a note — expose an accessibility action
  that makes the *same* edit, so the two paths cannot drift (added 2026-08-21).
- Review contrast in both themes. Primary touch targets ≥ ~44×44 pt.
- MUST NOT communicate state by color alone (e.g. a calendar dot needs an accessible label/trait).
- Testing matrix per major screen: Light, Dark, Light+large type, Dark+large type, Reduce Motion, VoiceOver.

---

## 5. Architecture rules

Source: `docs/05-architecture.md` (whole file), `docs/06-tech-stack.md`.

### Client style

- Feature-oriented native architecture. SwiftUI views + `@Observable` feature models where state is
  non-trivial + protocol-backed services where mocking matters + SwiftData behind a small `NoteStore`
  + environment-based DI + Swift Concurrency.
- MUST NOT build: one giant `AppViewModel`, massive singleton state, dozens of use-case classes for
  trivial reads/writes, or backend DTO concerns imported into UI.

### Data model

- `Note`: `id: UUID` (unique), `title: String?`, `body: String`, `createdAt`, `updatedAt`,
  `deletedAt: Date?` (non-nil only during short undo/cleanup state).
- `title` normalized: whitespace-only → nil. `body` stays raw user content.
- Structure lives **inside `body`** as canonical line markers (`# `, `## `, `- `, `1. `, `- [ ] `,
  `- [x] `). MUST NOT introduce a block database, a rich-text/attributed-string format, or a second field:
  `body` stays a single plain `String`.
- **Links and code live inside `body` too (added 2026-08-23, V2 Phases 1–2).** No new model, no second
  field, no migration — the same bargain tables struck:
  - a **link** is either a bare `http(s)` URL exactly as written, or `[text](absolute-http(s)-url)`,
    whose brackets and destination are hidden at the glyph layer and whose words are what the reader
    sees. A literal `]` in a label escapes as `\]`, as a cell escapes `\|`. Written only by paste.
  - a **code block** is a complete ` ``` ` fence pair. Every line between the fences is **literal**:
    `BlockKind.parse` does not run on it, `canonicalized` does not rewrite it, and no link is read out
    of it. A fence declaring `text` is a **preformatted block** (added 2026-08-25) — the same pair, the
    same literal lines, the same card; only the label and the absence of syntax colour differ. This is
    what lets an architecture diagram hold `#`, `- `, `1.`, `| … |` and `[x](y)` without any of them
    becoming structure.
  - `MarkupDocument` is the one place both are resolved. It carries `isLiteral` per line and hidden runs
    at arbitrary offsets, and its source↔visible mapping MUST stay **bit-identical** for any line that
    holds neither — that is a contract, pinned by tests, not an optimization.
- Timeline sorting & date grouping use `createdAt`, not `updatedAt`.
- No `voiceNote` type, no transcript provenance, no audio URL after successful transcription.

### Persistence & pagination

- SwiftData behind the `NoteStore` protocol (`createDraft`, `save`, `delete`, `undoDelete`, `recent`,
  `notes(on:)`, `noteDays(in:)`, `search`) so search/persistence stay swappable.
- Home is continuous UX but cursor/date-based batches under the hood (e.g. latest ~40, then
  `createdAt < oldestLoaded`). Stable key `createdAt + id`. MUST NOT use offset/page numbers.

### Date grouping

- Always use `Calendar` semantics (`startOfDay(for:)`, localized Today/Yesterday, explicit date intervals).
- MUST NOT do manual 24-hour math (`now - 86400`) — it causes DST bugs.

### Delete / undo

- Short-lived soft delete (`deletedAt = now`); normal fetches filter `deletedAt == nil`; undo sets it
  back to nil; cleanup after the undo window and/or on next launch for expired records. Do not rely
  solely on a transient UI `UndoManager` for persistence safety.

### Search

- V1 = local lexical search over normalized title + body. No embeddings / semantic search.
- If realistic-data performance is poor, migrate behind `NoteStore` to SQLite FTS5/GRDB without
  changing feature UI. Measure (100 / 1,000 / 10,000 notes) before optimizing.

### Backend

- Small Node.js 24 LTS + TypeScript + Fastify relay. Routes: `GET /health`,
  `POST /v1/app-attest/challenge`, `POST /v1/app-attest/register`, `POST /v1/transcriptions`.
- No user account, no note persistence. Flow: validate size/content-type → App Attest verify →
  rate limit → temporary handling → OpenAI transcription → validate response → return transcript →
  destroy temp audio.
- Return only `{ requestId, text, languages }`. Do NOT return model internals or raw provider errors.

### Error model

- Define domain errors (`TranscriptionError`: `microphonePermissionDenied`, `noSpeech`, `offline`,
  `requestTooLarge`, `rateLimited`, `serviceUnavailable`, `invalidResponse`, `cancelled`).
- UI maps domain errors to concise human copy. MUST NOT display raw backend/OpenAI errors to users.

### Migration

- SwiftData schema MUST be versioned deliberately before public release. Do not assume V1's model is
  permanent, but do NOT add speculative fields (pinnedAt, audio metadata, sync metadata) now.

### Configuration

- Do NOT hardcode API base URL, max recording duration, request timeout, model name, or rate limits —
  use environment/build configuration.
- However, fundamental product behavior MUST NOT be remotely mutable in unsafe ways (e.g. remote config
  MUST NOT be able to turn verbatim capture into AI rewriting).

---

## 6. Tech-stack rules

Source: `docs/06-tech-stack.md`.

- iOS: Swift 6+, SwiftUI, SwiftData, Swift Concurrency, `@Observable`, LocalAuthentication, AVFoundation,
  URLSession, DeviceCheck/App Attest, `@AppStorage`, OSLog, MetricKit, SF Symbols, String Catalogs
  (`.xcstrings`), Swift Testing (+ XCUITest where needed). Recommended min target **iOS 26+** _(V1)_.
- Backend: Node.js 24 LTS, TypeScript, Fastify, Zod/schema validation, official OpenAI Node SDK,
  model `gpt-4o-transcribe`, Redis-backed rate limit if needed, App Attest verification, metadata-only
  logs. `gpt-transcribe` is a benchmark candidate and must not replace production until the
  multilingual quality gate passes (§8).
- Audio: AVFoundation, prefer `AVAudioRecorder`, temporary `.m4a` mono AAC, level metering. Do NOT
  downsample so aggressively that recognition quality suffers.
- Networking: URLSession + Codable. No Alamofire. Timeout, cancellation, correlation/request ID, typed
  error mapping; never leak provider error messages to UI.
- MUST NOT lower the deployment target silently and then re-create modern controls by hand.
- MUST NOT force `.preferredColorScheme(.light/.dark)`.

### Dependency policy

Prefer **zero / very few** iOS dependencies. Before adding a package ask: (1) Does Apple provide this?
(2) Is it solving a proven V1 problem? (3) Does it add privacy/security surface? (4) Can the app
survive if it's abandoned? Likely V1 iOS third-party dependencies: **none** (unless search performance
later justifies GRDB). Backend dependencies are normal and isolated.

### Not for V1 (and why)

- No Realm/Firebase/Supabase — no account, no custom sync, no collaboration, no server note DB.
- No Algolia/Elasticsearch/vector search for a local personal-notes V1.
- No Realtime transcription first — final text after Done is the intended UX.

---

## 7. Do-not-build list

Source: `docs/01-product-requirements.md` §6, `docs/02-features.md` (Later section), `docs/05-architecture.md` §25.

### Excluded product features (V1)

accounts · Sign in with Apple · folders · tags · pinning · favorites · full rich text (font pickers,
text/background colors, arbitrary block types) · Markdown UI · images · attachments · scanning ·
handwriting · databases · table **editing** · kanban · nested workspaces · collaboration · comments · share
extension · widgets · watchOS app · reminders · notifications · journaling prompts · mood tracking ·
streaks · productivity analytics · AI summaries · AI rewriting · AI chat · semantic search · cloud note
storage · iCloud sync · export · audio archive.

**Sharing one note — a narrow exception (added 2026-08-26).** `export` above still reads exactly as it
did, and `share extension` still means what it says. What is admitted is neither:

- **`share extension` is the other direction.** It means As Told appearing inside *other* apps' share
  sheets, receiving content from them. That stays excluded. This is As Told handing **one note the
  person is looking at** to the system sheet.
- **`export` means the library.** Selected notes, a versioned backup file, a restore path — the Pro
  feature in `docs/09-v2-roadmap.md` §2.2, and still unbuilt and still Pro. Sharing the open note is
  **Copy with a destination attached**, and Copy has always been free (§3: a user who cannot get their
  own words out does not own them). `native Share Sheet` was already a §7 **P1 candidate**; this is
  that candidate shipping, not a new direction.
- **The system sheet, and nothing of our own around it.** No destination picker, no "Export as
  Markdown", no social buttons, no As Told share menu. iOS decides what appears, and it decides using
  what it already knows about that phone — which is the only version of that feature this app can have
  without learning any of it itself (§3).
- **Two representations of one item, never two attachments.** HTML for destinations that negotiate for
  it, UTF-8 text for the rest, both generated by `StructuredTextExport` — the exporter the pasteboard
  already uses. A second exporter would be a second thing to keep in step, and its first divergence
  would be a note that copies correctly and shares wrongly.
- **The latest edit is what is shared.** A table cell being edited lives in the card's own field until
  it commits, so Share MUST commit pending edits and read the **text view's** own text before building
  the payload. Sharing MUST NOT otherwise change the note: committing a cell is the writer's own edit
  landing through the ordinary undoable path, and nothing else about the note may move.
- **Never the placeholder.** An untitled note shares no title; the word `Title` is what an empty field
  draws to invite one, and it MUST NOT reach anybody's inbox.
- **An empty note has nothing to share.** Share stays **visible and disabled** rather than appearing
  and disappearing as the first character is typed — the header must not move while somebody writes.
  Emptiness is judged on visible text, the same test `Note.isEmptyDraft` applies.
- **No URL is invented for the sheet's header.** `LPLinkMetadata` gets the note's name and the app's
  icon. Handing it a fabricated web address would mean a link to nothing and a network request made on
  behalf of a note that never leaves the device.
- **Still forbidden:** an As Told account, an upload, a hosted note, a share *link*, collaboration, and
  any record of what was shared or where. Sharing is local, free, and unlogged.

**Tables — the one narrow exception (amended 2026-08-21).** This list read `tables`, flatly. It now
reads *table editing*, because those are two different products:

- **Allowed: import and display.** A table pasted from another app is preserved as canonical Markdown
  pipe rows inside `body` — ordinary text, no new model, no migration (RULES.md §5) — and *rendered*, so
  it reads as a table. This adds no way to *make* a table; it stops As Told from destroying one it was
  handed. A table asserts that these values belong to each other, and the row-record fallback it
  replaces kept every word while discarding that claim, which is the entire content of a table.
- **Two presentations, decided by who is looking (amended 2026-08-21).**
  - **Reading** — a real table view (`TableCardView`): a heading row, content-aware column widths, quiet
    horizontal separators, wrapping cells, no vertical rules and no spreadsheet grid. Not one pipe, and
    no delimiter row, may reach the screen. A table too wide to read on a phone shows a compact preview
    (the first columns and rows, and a line saying how much more there is) that opens the full-screen
    reader. **How a note stores a table is implementation, and a reader MUST NOT have to decode it.**
  - **Writing** — the canonical source, exactly as typed, save for the delimiter row, which is drawn
    nowhere (below). A table being edited is text being edited, and the caret has to be somewhere the
    writer can see it.
  - **Only the table the caret is in shows its source (amended 2026-08-23).** This read "the note returns
    to its tables the moment the body gives up the keyboard", which made *having the keyboard up at all*
    the condition — so tapping anywhere to add one sentence turned **every** table in the note back into
    pipe rows at once. A note of thirteen tables became thirteen blocks of raw syntax because of an edit
    happening somewhere else entirely, and the note looked broken. The condition is now the caret's
    position, not the keyboard's state: a table whose lines the caret or selection touches shows its
    source, every other table stays a card, and it returns to a card the moment the caret leaves.
  - **The delimiter row is storage, and is never drawn (amended 2026-08-23).** The **Writing** bullet
    above read "the canonical source, exactly as typed", and `| --- | --- |` was drawn along with it.
    It is the one line of a table's source that says nothing about the table's contents: it records
    which row is the header, nobody typed it to be read, and a row of dashes cutting the source in half
    makes the rows around it harder to read, not easier. So it is not drawn on **any** surface, reading
    or writing. It is **not removed** — `body` keeps every character, which is what lets the parser go
    on working, copy go on round-tripping, and every note that already exists get this without being
    rewritten. Two consequences are part of the rule, not implementation detail:
    - **A caret MUST NOT be left on it.** The line has no glyphs and no height, so a caret there is
      invisible, and the next keystroke would land inside the row that tells the parser where the
      header is — turning `| --- |` into a data row and the table back into prose. This is the §4 rule
      that keeps a caret out of a hidden block marker, applied to a hidden line.
    - **Backspace at the start of the first row joins that row to the header**, taking the hidden line
      with it. Joining it to the delimiter instead welds data onto the header rule
      (`| --- | --- || 20×30 |`), which stops being a delimiter and takes the table with it. What is
      left is still a table — two pipe rows without a rule — so the block degrades rather than breaks.
  - The presentation MUST NOT be a re-spacing of the source: hiding some characters and repositioning
    others (invisible tab stops for the pipes, a drawn hairline over the delimiter row) was tried and
    rejected on 2026-08-21 — it leaked stray pipes, banded backgrounds, and space-aligned columns, and
    the caret could land inside what looked like a rendered table. **That rejection is about *moving*
    things.** The rejected attempt left the source on screen and dressed it up, hiding some characters
    while repositioning others, so what the writer saw matched neither the text nor a table. Not
    drawing the delimiter row dresses nothing up and moves nothing: one line stops being drawn, and
    every other character stays exactly where it was typed.
- **Still forbidden: everything that makes it a spreadsheet.** No Table button on the writing toolbar,
  no graphical creation, no row/column insertion or deletion UI, no resizing, merged cells, sorting, or
  formulas, no cell-by-cell keyboard navigation, and voice MUST NOT create tables. Editing a table
  means editing its text, like every other line in the note.
- **The reader reads.** It MUST NOT gain an edit mode. The moment a cell can be typed into on that
  screen, this exception has become the feature it was written to exclude.

**Entering a note MUST NOT de-render a block the writer is not editing (added 2026-08-23).** This binds
every structured block — tables today, code blocks now, anything with two presentations later. Exactly
one block may show its source at a time: the one the caret or selection is inside. The change MUST hold
the caret's position **on screen** across the height difference, because a block flipping shape above the
caret otherwise moves the words out from under the writer's finger mid-sentence.

**A block MUST NOT be a dead end (added 2026-08-28).** This binds every structured block, for the same
reason as the rule above. When a rendered block is the **last thing in `body`** there is no line after it
to put a caret on: the closing fence is the end of the document, a caret may not settle on a fence
(above), and a table's last row is hidden behind its card — so every tap under the card resolved back
*inside* the block, and a writer who had just pasted a query could not write the sentence explaining it.

- A tap **below** a block that ends the note MUST open an ordinary paragraph after it and put the caret
  there, as one ordinary undoable edit against `body`.
- Exactly **one newline**, made **on demand**. Nothing may append a trailing paragraph to a block in
  advance: a note that ends in a block is a good note until somebody asks to write past it, and a blank
  line nobody typed would be in `body`, in Share, and in every copy of it (§5).
- The block MUST stay rendered across it — fences hidden, card drawn, source never exposed.

**Links — the second narrow exception (amended 2026-08-23, V2 Phase 1).** `full rich text` above still
reads exactly as it did. A link is admitted because it is not styling:

- **A link is a destination, not an appearance.** Bold and italic say how words should look; a link says
  where they go. That is why this does not open the door it looks like it opens — there is still no
  font picker, no colour, no size, no alignment, and no inline formatting of any kind.
- **Two spellings in `body`, and only two.** A **bare** `http(s)` URL is the characters the writer typed
  or spoke, read back as a link and never rewritten. A **labelled** `[text](url)` exists only where a
  clipboard stated a hyperlink whose text differs from its href. `[https://x](https://x)` MUST NOT be
  written — the app does not invent syntax around words nobody wrote.
- **Strict, like a table row's opening pipe.** A bare URL needs an explicit scheme (`apple.com` in prose
  is prose), and `[a](b)` is a link only when `b` is an absolute `http(s)` URL — so "[see](this)" keeps
  its brackets as words. **`http` and `https` are the only schemes**, and that is a security rule, not a
  formality: a tappable `javascript:` or `file:` run arriving from a clipboard is a hazard (§3).
- **The caret rule generalizes.** A caret MUST NOT sit *inside* hidden link syntax, the way it may not
  sit in front of a hidden marker. It may sit at a hidden run's leading edge — that is the end of the
  words before it, which is a place a writer is entitled to be.
- **Colour is never the only signal.** Links carry VoiceOver link semantics (`spokenText` says "Link, …")
  and gain an underline when Differentiate Without Color is on (§4).
- **Copy keeps both halves.** Rich-capable apps receive a real `<a href>`; plain-text apps receive
  `words — url`. "The page as it reads" would destroy a destination the writer put in their own note,
  and §3 says the note is theirs. This is a documented exception to the copy rule, like a table's source.
- **Still forbidden:** a link *button*, a URL-entry sheet, link previews, unfurling, favicons, an
  in-app browser, and link inspection UI. Editing a link means editing its text, like every other line.

**Code blocks — the third narrow exception (amended 2026-08-23, V2 Phase 2).** Fenced code is admitted
on exactly the terms tables were, plus one that is new and is the whole point:

- **Its characters mean nothing to As Told.** A `#` inside a fence is a comment, not a heading; a `- `
  is a YAML item, not a bullet. So a fence does not merely render differently — it switches marker
  parsing **off** for the lines inside it. Nothing may rewrite those lines, including on save.
- **Both fences required.** An unterminated ` ``` ` is ordinary text, so a stray fence can never swallow
  the rest of a note into a card.
- **Two presentations, decided by who is looking**, as with tables. **Reading** — a real `CodeBlockView`:
  monospaced, a quiet ground, indentation exact, long lines **scrolling** rather than wrapping, with
  **Copy Code**.
- **Writing — the block MUST still look like code (amended 2026-08-24, Item 5).** This rule previously
  read "the canonical fenced source, fences visible". That was honest about the storage and wrong about
  the note: tapping a code card replaced it with ```` ```python ```` and a wall of unstyled text, so the
  block visibly broke the moment anyone touched it. **The fences are storage — exactly like a table's
  `| --- |` row — and a reader MUST never have to look past them.** While a block is being edited:
  - both fence lines MUST have their glyphs hidden, and they carry **everything the card draws around
    the code** (amended 2026-08-28): the opening fence keeps the block's top margin, the header strip the
    language label and **Copy Code** are drawn into, and the card's top padding; the closing fence keeps
    the bottom padding and the block's bottom margin. It previously kept the header alone, so the editing
    presentation had no margin above the block while the reading one did, and moving focus to the title
    slid the whole block down the page. **Moving focus MUST NOT change where a block begins.**
  - the ground, the monospaced face, the language label, **Copy Code**, indentation, and **syntax colour**
    MUST all stay on. Colour is applied to the text storage so it survives every keystroke, and is still
    colour only — it MUST NOT insert, remove, or reorder a character.
  - the code between the fences MUST be edited **in place, in the note's own text view**. There MUST NOT
    be a second editor, a sheet, a separate code-document model, execution, autocomplete, or any other
    IDE behaviour (§7 is unchanged). It is a note that happens to contain code.
  - the caret MUST NOT be able to settle on a fence line (`CodeBlock.caretEscape`), and the fences and the
    stored language MUST NOT be editable through the visual surface. `body` stays canonical fenced source.
  - the language is whatever the fence stored. It MUST NOT be re-detected while typing.
  - **Accepted difference (V1).** Long lines **wrap** while a block is being edited, where a read block
    scrolls sideways. In-place editing means the note's own text container lays the code out, and a
    nested horizontal scroller around live editable text is the second editing surface this rule forbids.
  - A block with **no code in it yet** keeps its fences on screen: hiding both would leave an empty strip
    the writer can neither identify nor find their way into.
- **What a touch on the card does (corrected 2026-08-24).** This bullet read "selectable" flatly. The
  shipped card is not, and the wording was stale rather than the code being wrong — so this describes
  what ships: **a card is inert except Copy Code, in both modes.** Every other touch passes through to
  the editor, which is what puts the caret into the block. That is not a preference: a card that owned
  its touches while the source was hidden behind it left the block with **no way in** — a tap did
  nothing and the code could not be reached at all. Selecting part of a block means tapping into it and
  selecting the source, like every other line in the note; **Copy Code** covers taking the whole block.
  - **Selection while *reading* is undecided and unbuilt (2026-08-24).** A reader cannot select three
    lines out of twenty without first tapping in, which turns the card into source. Enabling selection
    only while reading is a real option — the card knows nothing about mode today, so it is a change to
    both the view and the presenter, not a flag — but it MUST NOT reintroduce the no-way-in bug, and it
    is not written down as a requirement until it is decided and built.
- **Scoped to the block the caret is in**, exactly as tables are (above). Entering the note MUST NOT
  de-render a block the writer is not editing. While the caret sits in a code card, that card is
  transparent to touches except **Copy Code**, so a tap reaches the text underneath and puts the caret
  in the code — otherwise a block whose source is hidden behind a card would have no way in.
- **Structure controls are withdrawn while the caret is in code.** The Style menu and its shortcuts MUST
  NOT be reachable there; applying one would write a marker into somebody's program.
- **Copy Code and copied text drop the fences.** They are storage delimiters, not user content. The
  private As Told → As Told representation still carries the canonical fenced source.
- **Syntax colour, and a language label (amended 2026-08-24).** This list read "and — for this pass —
  syntax highlighting", which was the right call for the pass that built the card and the wrong one to
  keep: a monochrome block does not meet the bar this exception set itself, because *code pasted into
  As Told should still look like code*, and code has never looked like one colour. Admitted on these
  terms, all of which are binding:
  - **Only inside a rendered `CodeBlockView`.** The editing presentation stays the plain canonical
    source. There is no syntax-aware editor, and building one would be the IDE this excludes.
  - **Only a language the source declared**, from a closed list As Told knows (`CodeHighlighting`). A
    language MUST NOT be inferred from the code's contents — that is the "short line is not a heading"
    rule (§2, §4) wearing a different hat. An undeclared or unrecognised block is drawn in one colour,
    exactly as it was before this shipped. ASCII diagrams, logs, and preformatted prose are not
    programs, and nothing may decide otherwise on their behalf.
  - **Five tokens, no more:** keywords, strings, comments, numbers, and the names being called
    (types/functions) — the one such distinction a scanner can make without guessing.
  - **Semantic adaptive tokens, measured.** Light and Dark are one definition, and every token clears
    **4.5:1 against `CodeSurface`** — the ground it is actually read on. A syntax colour is not exempt
    from the floor every other glyph in this app clears (§4). Looking like an IDE is not a reason to
    be harder to read.
  - **Colour only.** Highlighting MUST NOT alter `Note.body`, and MUST NOT change, reorder, or insert
    a single character of the code. **Copy Code still copies the original code**, fences dropped and
    styling with them.
  - **The label says what the source said.** A block whose fence named a language shows a quiet name —
    `SQL`, `Python` — at the top of the card. A block that named none shows **nothing**: not "Code",
    and not "Plain text" invented on its behalf. A label nobody wrote is a guess, and an empty corner is
    quieter than a wrong word.

    _(Amended 2026-08-25 — preformatted blocks.)_ "Plain text" is now a label a **source can state**,
    and stating it is not the same as inventing it. A fence reading `text`, `plaintext`, or `txt`, or a
    `<pre>` that never opened a `<code>`, has declared its characters preformatted; that block is
    labelled **Plain text**. The rule above is unchanged where it bites: a fence naming **nothing** —
    which is what **Paste as Code** writes — still shows no label at all.
- **Preformatted blocks — the same exception, one axis wider (added 2026-08-25).** An ASCII diagram, a
  directory tree, a column of aligned figures: text whose **alignment is its content**. It is admitted on
  exactly the terms above and adds nothing to them, because it is not a new structure — it is a fenced
  block whose declared language is `text`, read by the same parser, drawn by the same card, edited in
  place by the same rules, and copied by the same path. What differs is only what is true of it:
  - **The card says "Plain text" and shows no syntax colour.** `text` is not a language `CodeHighlighting`
    knows, so there is nothing to colour and nothing is special-cased to prevent it.
  - **Read three spellings, write one.** `text`, `plaintext`, and `txt` are all understood; every block
    As Told writes says `text`.
  - **`<pre>` means preformatted; `<code>` means code.** HTML states both outright, and the importer
    translates the claim rather than making one. A `<pre>` with no `<code>` inside it lands as plain
    text; a `<pre><code>` — with or without a language class — lands as code.
  - **High-confidence detection on paste (amended 2026-08-25, later the same day).** This clause first
    read "It is never inferred. There is no ASCII-art detector and there MUST NOT be one." That was the
    right call for the pass that built the card and the wrong one to keep, and the screenshots settled
    it: a clipboard carrying only `public.utf8-plain-text` — which is what a chat app's Copy button
    gives — arrived as prose, and proportional type threw its columns out of line immediately. The
    asymmetry §4 relies on runs the *other* way here. Code left as prose is a small disappointment
    fixed by one tap; **a diagram left as prose is unreadable**, because its alignment is its content.
    Admitted on these terms, all binding:
    - **Only real Unicode box-drawing characters count** — `│ ├ └ ─ ┌ ┐ ┬ ┼ ┤`, U+2500–U+257F. Never
      ASCII `|`, `-`, or `+`. Nobody types `├──` in a sentence; everybody types `|` and `-`. This one
      discriminator is what keeps a grocery list, a Markdown rule, `A | B`, and `A`/`|`/`B` out, and it
      is why a Markdown table can never be caught: its pipes are ASCII.
    - **Three lines and two independent signals**, never one. Each signal alone is plausible in
      ordinary writing; their coincidence — connectors that repeat, and repeat *in the same column* —
      is not something a sentence produces.
    - **Code is asked first.** `CodeDetection` answers only for languages `CodeHighlighting` can
      colour, and no program contains box-drawing characters, so the two cannot both claim a paste.
    - **It answers one question and no others**: "are these characters aligned art?" Nothing about what
      the art means (§2). It MUST NOT redraw, convert, or interpret the drawing.
    - **Anything short of certain stays prose**, with **Paste as Preformatted** as the writer's manual
      override — the same asymmetry, and the same escape hatch, that **Paste as Code** has.
  - **As Told MUST NOT interpret the drawing.** Not in the card, not in a preview, not to VoiceOver.
    `│`, `├`, `▼` are read as the characters they are; describing them as "a branch going down to
    Airflow" is As Told deciding what somebody's diagram means (§2). A screen reader is told **"Plain
    text block"** and then read the characters — the same courtesy a code block gets, and no more.
- **Still forbidden:** running code, a console, a terminal, a compiler, autocomplete, linting, an editor
  sheet of its own, inferred languages, ASCII-to-Mermaid conversion, Mermaid or any other diagram rendering,
  graphical diagram editing, and a second syntax-aware editing surface. The bar is unchanged:
  *code pasted into As Told should still look like code*, and a diagram pasted into As Told should still
  look exactly as its author aligned it — neither like an IDE, nor like a drawing tool.

> _(The manual theme selector was previously excluded but has been added — see §1. "checklists" was
> previously listed here as permanently excluded; reclassified 2026-08-18 as a guarded milestone, and
> **shipping in V1 as of 2026-08-19** — see "Adopted direction" below. Still not a task-management
> system. "Markdown UI" above means a Markdown **toolbar or preview mode**, which remains excluded; the
> typed marker syntax that produces a heading or a list is the shipped editor, not a Markdown UI.
> "reminders" and "notifications" stay excluded **from V1** and are reclassified 2026-08-20 from
> permanently excluded to a guarded **post-V1** direction — see "Post-V1 — note reminders" below.)_

### Adopted direction — sequenced and guarded

Repositioning As Told to "anything you want to put into words" makes a **very small** amount of writing
structure legitimate, built incrementally with hard guardrails. Full detail: `docs/02-features.md`
(Adopted direction) and `docs/08-positioning-marketing.md`.

**Milestones A and B were pulled forward and now ship in V1** (2026-08-19). They were planned as post-V1
work and this section described them that way; the code landed first and the rules had not caught up.
What follows is a record of that change, not a claim they were always V1 scope.

#### Shipped in V1 — Milestone A, structured writing

Implemented and covered by tests. Behavior locked as described:

- Block kinds: **paragraph, heading, subheading, bullet, numbered, checklist**. Nothing else
  (optional **quote** remains a later candidate).
- Canonical markers are stored **inside `body: String`** — the note stays plain text, no rich-text
  storage (§5). Markers are **visually hidden at the glyph layer, never removed** from the source.
- **Return** continues a list and exits an empty item; **Backspace** at line start demotes the block to
  a paragraph; the **checkbox gutter** toggles a checklist item.
- **Leaving a structure MUST move the caret immediately**, before any further input. The document being
  correct is not enough: the caret MUST be *drawn* at the paragraph inset the instant the marker is
  removed, by Return, by Backspace, or by Style → Paragraph. A caret that only corrects itself once a
  character is typed is a bug, and is pinned by caret-geometry tests rather than by text assertions.
- **List content is body text.** Bullet, numbered, and checklist lines MUST use exactly the paragraph
  font, line height, and Dynamic Type scaling; only the gutter marker differs, and it scales with the
  body font it sits beside. Caption/footnote typography MUST NOT be used for list rows or markers.
- **Structured copy/paste** carries the source markers; **undo/redo** stays native and exact.

#### Shipped in V1 — Milestone B, voice structure commands

- Vocabulary, exactly nine **actions**: **new paragraph · new line · heading · subheading · bullet
  list · numbered list · checklist · next item · end list**, each accepting the closed set of
  spellings listed in §2.
- Recognition is a **deterministic client-side parser**, not a model. Structure is applied **only on an
  explicit command**; anything uncertain stays literal text. This is the §2 contract in the editor:
  ordinary speech that merely *sounds* structured MUST NOT become a list.

#### Discoverability rule (added 2026-08-19, superseded the same day)

Structured writing MUST remain available **without a persistent formatting toolbar** — but it MUST NOT
require knowing marker syntax either. The original rule made typed markers and voice commands the only
ways in, with help surfaces that were reference-only. That shipped a capability most people would never
find: `- ` for a bullet is developer knowledge, and a note-taking app cannot make its structure
conditional on it.

**The rule now:** structure is available directly through a small contextual writing control. Typed
markers remain fast shortcuts, and voice commands remain the spoken equivalent. Three ways in, one
operation underneath.

- **The Style control shipped in V1** (2026-08-19), promoted from the post-release item this section
  previously described. Form: one contextual `Aa` toolbar item, present only while the **body** has the
  caret, opening a menu of the six structures with the current one checked, plus the writing-help
  reference. It routes through `DocumentAction.setBlockKind` — the same primitive typing and voice
  already used — so there is one document-action layer, never two formatting systems.
- **A menu, not a sheet**, and that is a behavioral requirement rather than a preference: a sheet
  resigns first responder, so the keyboard would drop and the selection being styled would have to be
  restored afterwards. The menu leaves the keyboard and the live selection intact.
- **It became the writing toolbar** (2026-08-20), and this bullet used to say the opposite: "a
  keyboard-accessory row of style buttons is the forbidden bar, not an alternative to it." That was
  written before the control had been lived with. In use, `Aa` in the navigation bar meant *tap Aa →
  read a menu → find Bulleted List* for the thing writers do most, with the control as far from the
  keyboard as the screen allows. The row now ships, floating above the keyboard, with the three list
  structures as direct buttons and Heading / Subheading / Paragraph behind `Aa`. It MUST stay
  contextual — gone while reading, gone while the title has the caret, replaced by the recording panel
  while recording — and it MUST NOT grow a scroll, a second row, or an overflow: what does not fit is
  what does not belong.
- **Applying a style acts on every line the selection touches, as one undo step.** Four lines becoming a
  checklist is one thing the writer did and MUST undo as one.
- **Nothing else joins this control.** Inline formatting — bold, italic, underline, highlight, colors,
  alignment, font size — is full rich text and stays excluded above. It is a different category
  (selection ranges, nested formatting, source↔visible mapping, copy/paste semantics), not a smaller
  version of what shipped.
- **Help surfaces stay reference-only.** The writing-help sheet explains syntax and applies nothing;
  applying is the Style menu's job. The standalone `?` was folded into that menu (2026-08-19), and the
  empty note's marker cheat-sheet was removed — its whole purpose was compensating for the absent
  control.
- **A checklist is content, not a task manager.** It means "write several things and tick them off." It
  MUST NOT bring due dates, deadlines, overdue states, priorities, recurrence, calendar scheduling, task
  inboxes, or notifications. A Todoist/Notion clone stays on the do-not-build list. This prohibition is
  **unchanged** by the post-V1 note-reminder direction below: a reminder attaches to a **note**, never to
  a checklist item, and no checklist item ever becomes schedulable.
- **Keep at Top** (surfacing an active draft/checklist above the chronological timeline) is evaluated
  *only after* structured writing exists — and is not a folders/favorites/workspace system.

#### Post-V1 — note reminders (decided 2026-08-20, NOT built)

Reminders and notifications are excluded outright above. Reclassified 2026-08-20 from *permanently
excluded* to a **guarded post-V1 direction**: a note may remind you. This records a product decision,
not work in progress. Nothing here is built, and none of it may start before §8 is green.

- **Note-level only.** As Told MAY detect explicit future reminder intent in ordinary note text and
  offer a **one-time local notification** that links back to the note. A reminder belongs to the
  **note**; the checklist rule above is untouched and still binding.
- **Suggest, never act.** Detection MAY suggest. It MUST NOT schedule. A reminder exists only after
  explicit confirmation, and the note text MUST NOT be rewritten, annotated, or given hidden reminder
  markers — `body` stays a single plain `String` (§5).
- **Local and deterministic.** Detection runs on device with no model call. A reminder-shaped sentence
  MUST NOT cause any note text to leave the device (§3).
- **One pipeline.** Detection runs against the resulting note text, so equivalent text produces
  equivalent behavior whether it was typed or spoken — the convergence rule voice structure already
  follows (§2). Paste MUST NOT proactively trigger detection.
- **Permission on use.** Notification authorization is requested only when the user confirms their
  **first** reminder — never at Welcome, never at launch, never on merely typing one (§4 core rule 4).
- **No task system.** MUST NOT introduce a reminders tab or dashboard, a task inbox, projects,
  priorities, completion state, overdue state, recurrence, snooze, or calendar sync.
- **No permanent editor chrome.** The Editor's element list (§4) is unchanged. A suggestion is
  **ephemeral and contextual** and goes away once answered; a standing reminder chip or a permanent
  keyboard-accessory row is the forbidden bar (§1), not a smaller version of it.

Preconditions — each is real work against the shipped architecture, not a bolt-on:

- **Schema.** A `Reminder` model requires `NoteSchemaV2` and a real `MigrationStage`
  (`Models/NoteSchema.swift` declares V1 with no stages). Prefer a plain `noteID: UUID` over a
  SwiftData relationship unless the relationship earns itself.
- **Deletion.** Note deletion is a reversible ~4-second soft delete (§5,
  `Core/Persistence/NoteDeletion.swift`). Deleting a note MUST **suspend** its notifications and Undo
  MUST restore them; only the final purge deletes reminder records. Still **no confirmation dialog** (§4).
- **Empty drafts.** A note with an active reminder MUST NOT be eligible for the automatic empty-draft
  purge (§4, `Note.isEmptyDraft`). A confirmed reminder MUST NOT be able to lose its note silently.
- **Navigation.** Opening a note from a notification needs an externally addressable destination that
  survives the lock flow; Home's navigation is local `@State` today. The pending destination MUST be
  held until authentication succeeds — a notification MUST NEVER bypass the app lock (§3).

### Marketing must lag implementation

- Marketing (App Store name/subtitle/keywords/description/screenshots, website, OG, social) MUST describe
  the **production app**, never the roadmap. MUST NOT claim headings / lists / checklists / voice-structure
  commands, or any other unshipped capability, until it works reliably in the shipping build.
- Concretely: the App Store subtitle stays the current narrower line until the broader editor ships; only
  then does it move to **"Notes, drafts, lists & voice."** Same for any website/ASO copy about structure.
- MUST NOT claim "offline transcription", "nothing ever leaves your phone", or any privacy/capability
  statement the production architecture does not actually guarantee (voice transcription involves server
  processing — see §3).

**Language claims (added 2026-08-28).** Marketing had been describing As Told as an *English / Telugu /
Hindi* app, which is a claim about the **benchmark**, not about the product. The relay deliberately does
not send a `language` parameter — forcing one would collapse code-switching (§2) — so the shipped
pipeline is multilingual, and the five groups in §1 are the ones whose quality is *measured* before a
release. Both halves of that are binding on copy:

- **MAY say** "multilingual voice transcription", "speak the way you actually speak", "switch languages
  naturally", "your words stay in the language you used", "no forced translation".
- **MUST NOT say** "all languages", "every language", a language *count* ("100+ languages"), "perfect
  transcription", or "understands any accent". None of those is measured, and a count is a promise about
  languages nobody has benchmarked.
- **English, Telugu, Hindi and the code-switched pairs appear as tested evidence, never as the
  headline** — worded so a reader understands them as what has been verified most closely, not as the
  only languages accepted. Where accuracy is discussed, say plainly that it varies by language, accent,
  and recording conditions.
- **Tightened 2026-08-29, after the words changed and the framing didn't.** The site was reworded to
  lead with the capability and still *looked* like a three-language product: `/languages` opened with a
  row of five chips (Telugu · Hindi · Telugu + English · Hindi + English · English) over a tabbed
  Telugu/Hindi example switcher, the homepage carried two devices captioned by language, and
  "Multilingual" sat in the primary navigation as if it were a fourth thing As Told is. A reader takes a
  chip row as the supported-language list no matter what the footnote under it says. So:
  the benchmark groups are named in **exactly one place — the Support answer for "Which languages can I
  speak?"** — and described there as release test groups. They must not appear in a hero, a chip or pill
  row, a tab bar, a screenshot caption, an image `alt`, a feature grid, or a CTA on any page. A
  screenshot of a mixed-language note is fine and welcome; **labelling it with the languages is not**.
  Multilingual is a property of voice, so it lives inside the voice story rather than in the site's
  primary navigation.
- **Tightened again 2026-08-29, on the pictures.** Removing the labels was not enough, because the
  *picture* is the claim. With the words fixed, the marketing site still closed its write-or-speak
  sequence with a Telugu/English note and illustrated its multilingual section with a Hindi/English
  one — uncaptioned, `alt` naming no language, and still teaching every visitor that As Told is an
  English + Telugu + Hindi app. So, **on the website**: no screenshot of a note written in a
  benchmark script, captioned or not. `hindi-light` and `voice-light` are deleted from
  `website/public/`; the raws stay in `docs/appstore/raw/` for testing. The multilingual argument is
  made by **the recording screen**, which carries no language control — *there is nothing to pick* is
  a claim a picture can actually prove, and an absence cannot be misread as a list.

  This binds the site, not the app and not the App Store listing: frame `03-languages` shows a
  mixed-language note under a caption that names no language, and a store visitor looking at ten
  frames of product is a different reader from someone deciding in five seconds what As Told *is*.

### Architecture non-goals (do not build)

server-side note database · event-sourced note history · microservices · Kafka · GraphQL · vector DB ·
auth platform · realtime collaboration stack · a sync engine before sync is a product requirement.

> The backend exists **only** because paid transcription credentials cannot safely live in the client —
> not because the product needs a traditional cloud backend.

### P1 candidates (only after stable V1, not now)

Optional iCloud sync (no custom account) · keep original audio (off by default) · ~~native Share
Sheet~~ (**shipped 2026-08-26** — per-note Share; see the share exception above) ·
export all (text/Markdown) · Lock Screen / Control Center quick capture · Apple Watch capture · manual
appearance override (only if users ask) · pin note (evaluate against chronological philosophy first).

---

## 8. Release gate — V1 is not shippable until all are true

Source: `docs/01-product-requirements.md` §15, `docs/07-build-plan.md` (Definition of Done).

- Typing flow, note persistence, and empty-draft cleanup are stable.
- Structure is reachable **without knowing marker syntax**: the Style menu applies each of the six
  structures, checks the current one, converts a multi-line selection in one undo step, and is absent
  while reading and while the title has the caret.
- Search is useful at realistic note counts (tested to ~10k).
- Calendar navigation works across months, years, timezones, and DST.
- Face ID / device authentication behavior is tested (enable/cancel/failure/background/foreground).
- App-switcher privacy cover is tested.
- Microphone permission denial/recovery is tested.
- Transcription error and offline flows are tested (airplane mode, slow net, 500, rate limit, timeout,
  empty result, user cancel, app backgrounds mid-request).
- Voice benchmarks pass agreed thresholds for: English, Telugu, Hindi, Telugu+English, Hindi+English —
  on the consented corpus, with the model chosen by `compareArms`, not by assumption.
- Recording survives interruption (call/Siri), route change (AirPods), and backgrounding; no temp
  audio survives a force-quit.
- No transcript/audio content appears in server logs; no embedded OpenAI secret; temp audio deletion verified.
- Relay runs with `APP_ATTEST_REQUIRED=true` in production. (It ships `false` only for the staged
  first-registration rollout in `transcription-service/DEPLOY.md`; shipping V1 with it false leaves
  a paid endpoint open.)
- The attested-key registry MUST be durable when `APP_ATTEST_REQUIRED=true`. Apple's replay defence
  is an ever-increasing assertion counter, which only rejects a replayed assertion if the stored
  counter survives restarts and deploys — a process-local registry silently disables it and
  re-registers every install. `APP_ATTEST_DB_PATH` MUST point at a mounted volume; the relay refuses
  to start if enforcement is on without it.
- The challenge store and rate limiter are still in-memory, so the relay MUST stay single-instance
  (`min_machines_running = 1`, `auto_stop_machines = "off"`). Scaling out requires a shared store
  first — otherwise rate limits multiply by instance count and challenges fail across machines.
- Light / Dark / Dynamic Type / VoiceOver reviewed on every major screen, over the full flow:
  Welcome → Home → New Note → Type → Read Existing Note → Edit Existing Note → Voice → Search →
  Calendar → Delete/Undo → Profile → Face ID.
- No user-facing surface says `Yourly`: UI copy, accessibility labels, display name, App Store
  listing, website, and support content all read **As Told**.
- The verification suite in `docs/07-build-plan.md` ("Verification suite") is green at **at least the
  current committed baseline**, with a clean typecheck and a succeeding Release build. As of this
  checkpoint that baseline is **1359 unit, 101 UI, 137 relay** (measured 2026-08-31 —
  full `-only-testing:YourlyTests` and `-only-testing:YourlyUITests` runs, both green, with a
  succeeding Release build and a clean relay typecheck. The UI figure is from the last full run, taken
  before the row-hierarchy and calendar passes — both of which, by agreement, added no UI tests. The
  row pass changed one view's typography and no label, identifier, or control. The calendar pass
  restructured a view hierarchy, so its two existing UI classes were re-run on their own and are
  green (4/4); nothing else on that screen's surface moved).

  Three changes are in this tree at once, and the number is **the tree's**, not any one of theirs:

  1. the Home library redesign and its three refinement passes — the recent-only scope, the caps and
     their reversible `Show all N` / `Show less`, the conditional `Browse older notes`, the restored
     date line and header tints, the row hierarchy in which only a title reads as one, and the
     calendar pass (one scroll, a 4-note day cap, sage state colour, density dots);
  2. the recorder lifecycle work — the `AVAudioRecorder` delegate, an unexpected stop that can
     neither leave the capture `recording` nor pass for an ordinary success, `.finishing` as a real
     gate before any upload, and a transient empty audio route that is checked rather than believed;
  3. the attestation repair — a 401 completed inside the request that was rejected, a stale local key
     replaced before the upload, and a guard that no other status gains a second attempt. The relay
     rose to 137 with the attestation-rejection log.

  **The earlier figures in this line (1280, 1292, 1297, 1303, 1308, 1320, 1334, 1340) were partial counts taken
  while those changes landed one at a time; the number above supersedes all of them.** Anything
  landing on top of this tree MUST **re-measure** and write the real number here rather than adding
  its own delta to this one.

  Earlier: 1280 unit and 92 UI measured 2026-08-28 —
  full `-only-testing:YourlyTests` and `-only-testing:YourlyUITests` runs, 1280 tests in 166 suites and
  92 UI tests, green, raised from 1202/83 by Voice V2 Phase 2B: retained recordings, the 24-hour
  lifetime and its sweep, Retry / Delete Recording, one-shot recovery of a recording that outlived its
  capture — including one left mid-upload — route-change policy, and background durability. The
  relay count is carried forward, not re-measured: no relay file was touched, so it cannot have moved.
  Earlier: 1134 unit measured 2026-08-26 in 146 suites; raised from 1102 by per-note Share; raised from 846 by preformatted /
  diagram blocks, high-confidence diagram detection, in-place code editing, the card pan rule, and
  live Differentiate Without Color updates. The
  UI and relay counts are **carried forward, not re-measured** in that pass: the UI suite was
  deliberately not run, and no relay file was touched, so its count cannot have moved. Earlier: 846 on
  2026-08-24, from 649/59/136, by V2 links, code blocks, rich paste, per-block card rendering, hiding
  the table delimiter row, pasted code whose lines are elements, and code syntax colour — all
  client-only work, which is why the relay count has not changed since).
  If additional tests are committed later, **the higher committed count becomes authoritative and this
  line MUST be updated** — a run that passes only the number written here while the suite has grown
  past it is a failure, not a pass. This line has gone stale three times ("305 unit, 33 UI", then
  "380 unit, 41 UI" while the suite was already at 474/53), each time leaving the gate guarding fewer
  tests than existed; re-measure rather than trusting it.
  The UI suite flakes
  as a whole-suite run, so a UI failure MUST be reproduced with `-only-testing:` on the single test
  before it is treated as a regression — and MUST NOT be waved off as flake without that check.

### Release-blocking voice behavior

Even with acceptable overall WER, release is blocked if the system frequently: translates Telugu/Hindi
to English · collapses mixed-language speech into one language · invents content during silence ·
"improves" meaning · loses large sections of speech.

Release is also blocked unless all of these hold:

- The monthly allowance is enforced **server-side**, on durable storage that survives a relay restart
  and deploy. A client-side counter is not enforcement.
- Reserving allowance is **atomic** — two concurrent requests at 59 minutes MUST NOT both pass.
- A failed or speechless transcription **refunds** its reservation, verified by test.
- Reaching the ceiling returns `monthly_voice_limit` with `resetsAt`, distinguishable from
  `rate_limited`, and the app shows the allowance dialog rather than a generic failure.
- The recording that crosses the ceiling succeeds, carries `allowanceExhausted` + `resetsAt`, and
  the following microphone tap is refused locally without opening the recorder — verified by test.
- No usage meter, credit count, or upgrade call to action appears anywhere in the shipped app.

---

## 9. Build order (do not reorder without reason)

Source: `docs/07-build-plan.md`.

Build in **vertical slices** — prove the typed-note product loop before any voice/backend work.

`Phase 0` foundation → `1` first-run + Home shell → `2` Note model + editor → `3` Home timeline →
`4` delete + undo → `5` search → `6` calendar → `7` settings + privacy lock → `8` audio capture UX
(with a **fake** transcription service) → `9` transcription backend → `10` real transcription
integration → `11` language quality program → `12` premium polish → `13` privacy / App Store readiness.

- MUST NOT start by building transcription/backend while Home and Editor do not exist.
- Phase 8 audio UX is perfected against a deterministic **fake** service before Phase 9 backend exists.
- First ticket: `APP-001 — Create native project foundation` (see `docs/07-build-plan.md`).
