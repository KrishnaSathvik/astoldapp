# Feature Specification

## Priority legend

- **P0** — required for V1
- **P1** — strong post-V1 candidate
- **Later** — intentionally out of current scope

---

## P0 — First-run welcome

### Purpose

Explain the product once without turning onboarding into a setup process.

### Content

- app mark
- app name
- **Write it. Say it. Keep it.**
- short private-space explanation
- Continue

### Rules

- one screen
- shown once
- no account
- no notification permission
- no microphone permission
- no Face ID permission

### Acceptance

- Continue takes user directly to Home.
- Relaunch does not show Welcome again.
- Resetting local app data can restore Welcome.

---

## P0 — Home timeline

### Purpose

Home is the complete notes history.

### Behavior

- newest note first
- grouped by date
- continuous scroll
- lazy loading behind the scenes
- title + preview
- no note timestamps
- Calendar action
- native search behavior
- floating/anchored New Note control

### Group labels

- Today
- Yesterday
- localized formatted date for older groups

### Acceptance

- User never needs a separate All Notes page.
- 500+ generated notes remain navigable.
- Loading older data does not block the main thread.
- No visible pagination UI appears.

---

## P0 — New note

### Action

Tap `+`.

### Behavior

- editor opens immediately
- date assigned automatically
- body receives focus
- title remains optional
- autosave starts after content exists

### Empty-note rule

A draft containing no meaningful title or body is removed when abandoned.

### Acceptance

- Repeatedly opening and backing out does not create empty Home rows.

---

## P0 — Note title

### Rules

- optional
- plain text
- no requirement/error if empty
- whitespace-only value normalizes to no title
- Home never displays `Untitled`

### Home rendering

If title exists:
1. title
2. body preview

If no title:
1. body preview as primary content

---

## P0 — Plain text editor

### Purpose

Make the app feel like writing directly onto the screen.

### Rules

- no visible border
- no formatting toolbar
- no rich text controls
- body uses comfortable line height
- normal iOS text editing behavior remains available
- selection/copy/paste work normally
- text is editable after voice insertion

### Opening intent: capture vs read

One screen, no mode toggle. What differs is only whether anything takes the keyboard on arrival.

| Opened from | State on arrival |
|---|---|
| New note (compose) | body focused, keyboard up — the user came to write |
| Existing note (Home / search / calendar) | reading: nothing is first responder, no keyboard |

From the reading state, tapping the title starts title editing and tapping the body places the caret
where the user tapped. Both raise the keyboard at that moment, and nowhere else.

### Keyboard dismissal

Native paths only — interactive dismissal while scrolling the body, navigating Back, and a trailing
`Done` that appears **only while a field holds the keyboard** and only dismisses it. There is no
custom "Hide Keyboard" bar, and `Done` never navigates (autosave already saved).

### Acceptance

- VoiceOver can focus title/body separately.
- Dynamic Type does not clip controls.
- Keyboard appearance respects system mode.
- Opening an existing note shows no keyboard; opening a new note shows one.
- Scrolling the body downward dismisses the keyboard interactively.
- `Done` is absent while reading, present while editing, and leaves the editor on screen.

---

## P0 — Autosave

### Trigger strategy

- debounced during typing
- immediate flush when leaving editor
- immediate flush when scene becomes inactive/background
- immediate flush after successful voice insertion

### Acceptance

- force-quitting after a save flush does not lose the note.
- user never sees a Save button.

---

## P0 — Edit existing note

Tap any Home/search result.

### Behavior

- opens same editor used for creation
- opens in the **reading** state: existing title/body load, keyboard hidden
- editing begins on tap, at the tapped location
- edits update `updatedAt`
- note remains sorted by creation date in V1

### Important rule

Editing an old note should **not** move it to Today.

The timeline is based on when the thought/note was created, not the last edit.

---

## P0 — Swipe delete + Undo

### Behavior

- swipe left
- destructive Delete action
- note disappears immediately
- Undo snackbar/banner appears briefly
- Undo restores exact note

### Implementation recommendation

Use soft-delete metadata briefly, then purge after Undo window/next cleanup pass.

### Acceptance

- deleting and immediately undoing restores title/body/dates exactly.
- app restart safely cleans expired soft-deleted records.

---

## P0 — Search

### Entry

Native-style search from Home, preferably pull-down `.searchable`.

### Search fields

- title
- body

### Result fields

- title or first meaningful line
- body excerpt
- note date

### Rules

- search is lexical in V1
- no embeddings
- no semantic AI search
- no search query analytics

### Acceptance

- case-insensitive matching for normal Latin text
- Unicode-safe matching
- Telugu and Hindi queries are tested
- empty query returns normal Home state

---

## P0 — Calendar navigation

### Presentation

Sheet.

### Month view

- standard month grid
- date with notes gets a small dot
- selected date gets native/high-contrast selection
- Today is easy to return to

### Rules

- dot means one or more notes; no heatmap
- no engagement count
- calendar does not become a second database UI

### Acceptance

- month boundaries work
- timezone/daylight-saving boundaries do not misgroup notes
- tapping a day with notes shows that day
- tapping an empty day has a clear empty state

---

## P0 — Voice recording

### Entry

Microphone icon in editor.

### First use

Request microphone permission only when the user taps the mic.

### Recording UI

- editor stays visible
- waveform/level visualization
- elapsed time
- Cancel
- Done
- no emoji
- subtle haptic start/stop

### Cancel

- discard current recording
- return to unchanged note
- delete temporary audio

### Done

- stop recording
- transition to `Transcribing…`
- preserve the insertion anchor captured when recording started
- send recording for transcription

There is no third `Stop` control: this recorder has no review-before-transcribe step, so a separate
Stop would be Done under another name (RULES.md §4). Cancel and Done are the whole state machine.

### Where the transcript lands

Decided when the mic is tapped, then owned by that recording:

| State when recording started | Result |
|---|---|
| Caret in the body | inserted at the captured caret |
| Reading, keyboard hidden | appended to the end of the note |

Reading stays reading — the keyboard does not reappear after an appended transcript. Voice never
creates a separate object; it is another way of writing into the same note.

### Interruptions

A call or Siri ends the recording; the capture finishes with the audio recorded so far rather than
discarding what the user already said. Leaving the editor mid-recording cancels the capture and
deletes the temporary audio. Recordings orphaned by a crash are swept at next launch.

---

## P0 — Voice transcription

Full contract: `04-voice-transcription.md`.

### Target language set

- English
- Telugu
- Hindi
- English + Telugu
- English + Hindi

### Output

Plain editable text inserted into note.

### Forbidden transformations

- translation
- summarization
- rewriting
- tone changes
- grammar polishing
- turning Telugu/Hindi into English by default

### Network

Required in V1.

---

## P0 — Voice failure/retry

### Cases

- no network
- request timeout
- service error
- invalid/empty audio
- microphone interruption
- permission denied
- transcription returns empty text

### Behavior

Never invent replacement text.

Provide concise actions such as:

- Retry
- Discard

Keep temporary audio only as long as required for explicit Retry.

---

## P0 — Face ID / device authentication lock

### Settings label

`Lock with Face ID` on Face ID-capable devices.

### Behavior

- opt-in
- authenticate when enabling
- cover content when leaving active state
- authenticate on return
- use system authentication UI
- allow system passcode fallback where appropriate

### Acceptance

- denied/failed authentication does not expose note content
- app switcher snapshot does not expose notes while lock is active
- system permission sheets do not create accidental lock loops

---

## P0 — Appearance (Theme)

### Rule

Appearance is user-selectable in Profile → Settings → **Theme**: Light / Dark / Use device settings
(default). When "Use device settings" is chosen, the app follows iOS appearance. The choice persists
and is applied app-wide.

### Acceptance

Every screen reviewed in:

- Light
- Dark
- increased text size
- increased contrast where practical

---

## P0 — Settings

Keep small.

### Privacy

- Lock with Face ID toggle

### About

- Privacy
- About `As Told`
- Version

No feature cemetery.

---

## P0 — Privacy cover

When app lock is enabled and app is not active:

- cover/replace note content before system snapshot
- do not leave readable text visible behind lock UI

This is separate from Face ID itself and should be implemented deliberately.

---

# P1 candidates

## Optional iCloud sync

No custom account.

Only consider after local V1 is stable.

## Keep original audio

Off by default.

Would require a different storage/privacy design.

## Share note

Native Share Sheet.

## Export all

Plain text / Markdown / archive.

## Lock Screen / Control Center quick capture

Fast entry to a new note or voice capture.

## Apple Watch capture

Speak a thought from Watch and store it.

## Pin note

Could conflict with purely chronological philosophy; evaluate before building.

---

# Adopted direction — post-V1 (sequenced, guarded)

Adopted 2026-08-18 with the "anything you want to put into words" repositioning (`README.md` §2,
`docs/08-positioning-marketing.md`). These are **not V1 scope** and MUST NOT be marketed until shipped
(`RULES.md` §7 — marketing lags implementation). Build in order; do not build everything at once. The
overriding constraint: the app must still feel almost as simple as today (`docs/01` §14 success test).

## Milestone A — Structured editor

Give the plain-text editor a **very small** amount of structure so drafts, lists, plans, and checklists
are possible on the same universal document. No document types; the page never asks what the writing is.

Supported structures (and only these):

- normal text (default)
- heading
- subheading
- bullet list
- numbered list
- checklist (content — tick items off; **not** a task manager)
- quote (optional, later)

### Rules

- Delivered as contextual / collapsible native affordances (contextual control, collapsible keyboard
  accessory, selected-text menu, conservative typed-shortcut recognition). **No persistent formatting
  ribbon.** Formatting MUST NEVER visually dominate writing; the app still reads as a page (`RULES.md` §1).
- Typed shortcuts (e.g. `- item`, `1. item`) may become lists **only on a clear signal**; when uncertain,
  preserve exactly what the user typed.
- Long-form must feel *better* as a document grows, not more cluttered: comfortable typography, generous
  leading, stable cursor, responsive scrolling, reliable autosave, good selection, long-document performance.
- A checklist MUST NOT introduce due dates, deadlines, overdue states, priorities, recurrence, scheduling,
  task inboxes, or notifications. That is a task manager, and stays on the do-not-build list.

### Undo

Structure is one of the most visible things the editor does, so it MUST be as undoable as typing
(`RULES.md` §4). **One user action is one undo step:**

| Action | Undo restores |
|---|---|
| Return continuing a list / checklist | the line as it was, with no stray line break left behind |
| Backspace demoting a structured line | the marker, hidden and styled again |
| Tapping a checkbox | the previous tick state, caret untouched |
| A voice transcript landing at the caret | the note without the transcript |

- Structural operations are applied through the text view's own edit primitive, never by assigning the
  whole string — that bypasses undo registration entirely.
- UIKit registers an *incomplete* undo for a replacement spanning a paragraph break (undoing `\n- ` leaves
  the newline), so a structural edit suppresses UIKit's registration and registers its exact inverse.
- Undo restores the styling and never leaves the caret inside a hidden marker; redo reapplies the edit.

### Copy, cut & paste

Structure is stored as hidden line markers inside `body`, so nothing that leaves the editor may carry
them (`RULES.md` §4).

| Direction | What travels |
|---|---|
| As Told → another app | the page as it reads: `Shopping`, `• Eggs`, `☐ Call Ravi`, `☑ Done`, `1. one` |
| As Told → As Told | the raw source, via a private pasteboard type (`com.astold.structured-text`) |
| another app → As Told | plain text, exactly as pasted |

- Copying a visibly complete list item copies the item: the selection expands over that line's hidden
  marker, and cutting takes the marker with it rather than leaving an orphan.
- A selection that starts mid-line is a fragment, and carries no marker.
- A pasted structure may take over the caret's line only when nothing of that line survives the paste;
  otherwise the first pasted line joins as words, with its marker dropped. A marker MUST NEVER land
  mid-line, where it would read as literal text.
- Home and search previews render the same visible text, never the markers.

### Acceptance

- A user can write a 2,000+ word draft comfortably, and a bullet list / numbered list / checklist, in one
  note, without a mode switch — and Home/Editor still feel minimal.
- Copying a checklist into Messages pastes `☐ Call Ravi`; copying it back into As Told restores a real
  checklist item.

## Milestone B — Voice structure commands

Extend voice from speech-to-string to **speech-to-document**, on the same document model — no separate
voice-only note system. Only after Milestone A structures are stable.

- Small, fixed, deterministic vocabulary: `new paragraph`, `new line`, `heading`, `subheading`,
  `bullet list`, `numbered list`, `checklist`, `next item`, `end list`.
- Conservative parser (`RULES.md` §2 "Structure the words"): recognize a command only as a clearly
  isolated phrase at an utterance boundary using exact wording; **when uncertain, preserve the spoken words**.
- No generative inference of formatting. *Touch chooses where; voice chooses what* — no hands-free
  navigation/selection/deletion this stage.
- English commands may ship first; Telugu/Hindi equivalents evaluated separately and MUST NOT degrade
  code-switch transcription quality.

- A recognized command absorbs the whole punctuation run after it — `new paragraph...`, `heading…`,
  `checklist!` — so no stray punctuation is left in the note. This does not widen recognition: the phrase
  still has to sit at a sentence boundary and be followed by punctuation or the end of the transcript.

### Acceptance

- Speaking "Checklist. Finish screenshots. Next item privacy page. Next item TestFlight." produces a
  three-item checklist; speaking the literal words "new paragraph" mid-sentence, ambiguously, keeps the words.
- "New paragraph... I visited in January." leaves no dots behind; "The heading was completely wrong." stays
  words.

## Milestone B2 — the "Style" control (post-release, design-test first)

Structure can be created two ways today: typing a marker (`- `, `# `, `1. `) and the voice commands.
Converting an *existing* paragraph — "make this a heading" — has no UI path, because
`DocumentAction.setBlockKind` is implemented and tested but deliberately has no caller.

This is a real usability hole and an explicitly accepted one. It does **not** block release: the
capability exists, and destabilising a freshly landed editor to add a control we have not design-tested
is the worse trade.

When it is built:

- A single contextual **Style** action offering: Paragraph · Heading · Subheading · Bullet · Numbered
  list · Checklist. It routes through the existing `setBlockKind` primitive — no second formatting path.
- Available **only while editing**, never in the reading state.
- Preferred entry point: a small `Aa` keyboard-accessory action. Acceptable alternatives to test: the
  text-selection context menu, or an editor `…` menu shown only when the cursor is active.
- MUST NOT become a persistent `B I U H1 H2 • 1. ☑` ribbon across the editor (RULES.md §1, §4).
  Formatting must never visually dominate writing.

Design-test the entry point before implementing. Nothing else joins this control.

## Milestone C — Keep at Top (evaluate later)

Broader writing means an unfinished draft/checklist may need to stay visible for several days instead of
scrolling into history. A future, opt-in **Keep at Top** surfaces such a note above the chronological
timeline, with an explicit "Remove from Keeping" that returns it to its natural date position.

- Evaluate **only after** structured writing exists and users actually keep active drafts around.
- NOT folders, favorites, tags, or a workspace. The timeline stays the primary organization model.

---

# Later / explicitly not planned now

- folders
- tags
- collaborative notes
- templates
- tasks
- reminders
- streaks
- mood tracking
- generative prompts
- AI writing suggestions
- AI summaries
- note chat
- semantic embeddings
- public profiles
- web social feed
