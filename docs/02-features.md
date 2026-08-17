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

### Acceptance

- VoiceOver can focus title/body separately.
- Dynamic Type does not clip controls.
- Keyboard appearance respects system mode.

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
- existing title/body load
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
- preserve intended insertion position
- send recording for transcription

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

## P0 — System Light/Dark appearance

### Rule

The app follows iOS appearance.

No in-app theme selector in V1.

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
- About `[AppName]`
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

## Manual appearance override

System / Light / Dark.

Only add if users ask.

## Pin note

Could conflict with purely chronological philosophy; evaluate before building.

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
