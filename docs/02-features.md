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
- one floating writing toolbar above the keyboard, and nothing above the page (Milestone B2)
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

Navigation push inside Home's stack (system back button). Originally specified as a sheet — the
push shipped and is kept; see `docs/03-design-system.md` §4.6.

Selecting a day does not navigate: that day's notes are listed under the grid, and tapping one opens
it from the calendar, so Back returns to the calendar with the day still selected. _(Changed
2026-08-19 — this replaced a mode where choosing a day sent the reader back to a filtered Home.)_

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
- tapping a day with notes lists that day's notes under the grid, without navigating
- tapping another day swaps the list; no stale notes from the previous day remain
- tapping a note opens it, and Back returns to the calendar with the same day selected
- tapping an empty day has a clear empty state
- deleting a note opened from the calendar is offered there and is undoable there

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
- monthly voice allowance reached

### Behavior

Never invent replacement text.

Provide concise actions such as:

- Retry
- Discard

Keep temporary audio only as long as required for explicit Retry.

The monthly allowance is the one case that is not a failure of the recording, and it behaves
differently: it gets its own title ("Voice will be back soon"), a single `OK`, and no Retry — the
same upload would be refused again. It also gets no upgrade call to action, because no Pro tier
exists (RULES.md §1). No recording is ever lost to it: the transcription that reaches the limit
still returns its words and tells the app so, and the app then refuses the *next* microphone tap
before the recorder opens.

### Acceptance criteria

- a single recording stops at 5 minutes and transcribes what was captured, never discarding it
- tapping the mic again after the cap continues at the cursor
- the recording that reaches the monthly ceiling still succeeds and inserts its text
- the mic tap after that refuses before the recorder opens, with no permission prompt
- no minutes used or remaining appear anywhere in the app
- the reset date shown comes from the relay and is rendered in local time
- typing, editing, search, and the calendar are unaffected by the allowance

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

# Adopted direction (sequenced, guarded)

Adopted 2026-08-18 with the "anything you want to put into words" repositioning (`README.md` §2,
`docs/08-positioning-marketing.md`). Build in order; do not build everything at once. The overriding
constraint: the app must still feel almost as simple as today (`docs/01` §14 success test).

> **Status, 2026-08-19 — Milestones A, B, and B2 shipped in V1.** All three were planned as post-V1
> work and this section described them that way; they were pulled forward and the implementation
> landed before the docs were updated. Their sections below are now **descriptions of shipped
> behavior**, not plans. Milestone C and everything after it remain unbuilt. Marketing still lags
> implementation (`RULES.md` §7): shipped is the bar for claiming a capability.

## Milestone A — Structured editor — **shipped in V1**

Gives the plain-text editor a **very small** amount of structure so drafts, lists, plans, and checklists
are possible on the same universal document. No document types; the page never asks what the writing is.

**As built** (`Core/Editor/StructuredText.swift`, `StructuredTextRendering.swift`,
`Features/Editor/BodyTextView.swift`):

- Canonical markers live **inside `body: String`** — `# `, `## `, `- `, `1. `, `- [ ] ` / `- [x] `. The
  trailing space is part of the marker; without it the line is ordinary text.
- Markers are **hidden at the glyph layer, never removed**. The source string always holds them, which is
  what keeps search, structured copy/paste, undo, and voice insertion working on one set of offsets, and
  what lets SwiftData keep storing plain text.
- **Return** continues a list and exits an empty item. **Backspace** at line start demotes to paragraph.
  The **checkbox gutter** toggles an item. All of it routes through the shared `DocumentAction`
  operations, so typing and voice perform the same edits.
- Structure is created three ways — the Style menu (Milestone B2), a typed marker, a spoken command —
  all routing through the same `DocumentAction` operations (`RULES.md` §1). Typing a marker is the
  shortcut, not the requirement.

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
| another app → As Told | the structure that app *states* — heading, list, checklist, table — and otherwise the plain text, exactly as pasted |

- Copying a visibly complete list item copies the item: the selection expands over that line's hidden
  marker, and cutting takes the marker with it rather than leaving an orphan.
- A selection that starts mid-line is a fragment, and carries no marker.
- A pasted structure may take over the caret's line only when nothing of that line survives the paste;
  otherwise the first pasted line joins as words, with its marker dropped. A marker MUST NEVER land
  mid-line, where it would read as literal text.
- Home and search previews render the same visible text, never the markers — and never a table's
  pipe source either (`StructuredTextExport.previewText`, 2026-08-21). A table is drawn on the note
  page and nowhere else, so every other surface that shows a note *as text* shows its cells, joined
  by `·`, with the delimiter row gone. Home read `| Day | Date | Schedule |` out of `body` until
  then. The pasteboard is deliberately not part of this: copying a table still yields its source.
- **The caret may never sit in front of a hidden marker, not only inside one** (2026-08-21). Marker
  glyphs have zero advancement, so every point in the list gutter — and one step right from the end
  of the line above — resolves to the line start, which is the marker's own first character. Left
  there, the next keystroke inserted *before* the marker and `- Eggs` became the literal text
  `X- Eggs`: the bullet gone and an internal marker on screen. The caret snaps to the line's first
  visible character, and text arriving at a range no caret was drawn at — a drag and drop, dictation,
  an autocorrect replacement — lands after the marker rather than in front of it. A *selection*
  starting at a line start is untouched: it means "this whole line", marker included.

**Pasting in from another app** (`Core/Editor/RichPasteImport.swift`, `RichPasteHTML.swift`,
`RichPasteMarkdown.swift`, `RichPasteDocument.swift`). Each reader translates its own format into one
shared `ImportedBlock` list — heading, subheading, paragraph, bullet, numbered, checklist, table — and
`RichPasteDocument` turns that into canonical As Told source. The table case exists only for the length
of a paste and is never a block As Told stores. A clipboard
usually carries the same content several times over, and the plain-text flavor is the one that has already
had the structure stripped out of it. The flavors are read richest-first, and the first that states
structure As Told already has wins:

| Order | Flavor | What is taken from it |
|---|---|---|
| 1 | `com.astold.structured-text` | the exact source — As Told → As Told is unchanged |
| 2 | `public.html` | `<h1>` → Heading, `<h2>`…`<h6>` → Subheading, `<ul>`/`<ol>` → Bulleted/Numbered, a list item with a checkbox → Checklist, `<table>` → its cells |
| 3 | `public.rtf` / flat RTFD | list structure, from the attributed string's own `NSTextList` |
| 4 | a declared Markdown type | `#` → Heading, `##`…`######` → Subheading, `-`/`1.` → Bulleted/Numbered, `- [ ]` → Checklist, a pipe table — a header row **with the delimiter row under it** — → its cells (`RichPasteMarkdown`) |
| 5 | plain text | the text, pasted exactly as it arrived |

- **A list item is a list item however it is wrapped.** Google Docs, Notion, and GitHub all write
  `<li><p>…</p></li>` or `<li><div>…</div></li>`. The block element inside the item ends a *line*, not
  the item, so the bullet, number, or checkbox survives it. (Until 2026-08-20 it did not: the nested
  block reset the item's kind, which flattened those lists — and, for an `<ol>` or a task list, could
  leave the whole document with no stated structure at all and drop it to plain text.)
- **A Markdown table needs a Markdown table's evidence** (2026-08-21). A table opens on a header row
  with the delimiter row directly under it, and nowhere else. Reading any line that merely held a pipe
  as a table meant `Option A | Option B` came back as a two-cell grid *and* As Told wrote the
  `| --- | --- |` under it — a whole line the source never showed, which is precisely the inventing
  that paste must not do. A line that opens no table is read as the prose, heading, or list item it is.
- **Markdown is read only when the pasteboard says it is Markdown** (`net.daringfireball.markdown`,
  `public.markdown`, `text/markdown`). A declared format states its structure exactly as HTML does.
  Text that merely *looks* like Markdown is text and reaches step 5 untouched — `**Overview**` in a
  plain-text clipboard stays those characters, and `- Jacket` is not read as a bullet by this reader.
  Markup for styling As Told does not have loses the markup and keeps every word: `**bold**` → `bold`,
  `[Major Marine](https://…)` → `Major Marine`. The address goes with the styling; writing it into the
  note would be adding text the source never showed.
- **Structure is translated, never inferred.** An `<h2>` becomes a Subheading because the source said it
  was a heading. A plain-text clipboard reaches step 5 untouched: nothing in the text is read as structure,
  and a short line is not a title. Rich text is treated the same way — a heading in RTF is only larger,
  bolder type, and type size is not a statement about structure, so nothing reads one from it.
- **Accepted limitation — line-leading markers in pasted plain text.** External plain text is inserted
  character-for-character. Because As Told's canonical source syntax recognizes line-leading structure
  markers such as `# `, `- `, `1. `, and `- [ ] `, those sequences may render as structure after paste.
  As Told does not otherwise infer structure from plain text. Telling "typed as a marker" from "pasted as
  text" would take escaping or per-line metadata in `body` — a storage redesign, deliberately not attempted
  for V1 (`RULES.md` §4). The same limitation applies inside preserved literal text: a line of a `<pre>`
  block or a fenced Markdown block that itself begins `# ` or `- ` renders as that structure. Its
  characters are unchanged, and no zero-width marker or invisible metadata is invented to beat the
  renderer. Note the narrower claim this makes: plain text is inserted verbatim and receives
  *no rich-clipboard structure inference*, which is not the same as "plain text never becomes structure".
- **Every word is preserved.** Nothing is corrected, reordered, reworded, or summarized (`RULES.md` §2).
  Inline styling As Told does not have — bold, italic, links — loses the styling and keeps its text. A
  block drawn entirely in bold is **not** read as a heading: large bold type is not a heading (`RULES.md`
  §4), and As Told keeps the words and drops the weight.
- **A checkbox glyph inside a declared list is a checkbox.** `<li>☐ Passport</li>`, and the same line
  under an `NSTextList` whose marker format is a box or a check, import as real Checklist items — the
  markup states the list, so the glyph in front of the words is that item's marker, exactly as `•` is.
  The identical glyph in a paragraph, in a heading, or anywhere in plain text is a character the writer
  typed and stays one. (Rich text used to reduce `☐`/`☑` to a bullet, discarding the one thing worth
  keeping; fixed 2026-08-20.)
- **This adds no formatting capability.** It only lets paste reach the structures the editor already ships.
- **A table stays a table** (changed 2026-08-21; this previously converted wide tables into one record
  per row). Imports canonicalize to Markdown pipe rows in `body` — ordinary text, no new model, no
  migration — and `TableBlock` reads them back:

  ```
  | Day | Date | Park         | Overnight |
  | --- | ---  | ---          | ---       |
  | 1   | Sat  | —            | Anchorage |
  ```

  - **Reading the note, the table is a real view.** Its source lines give up their glyphs and keep only
    their height, and a `TableCardView` sits in the space they reserved: a heading row, content-aware
    column widths, quiet horizontal separators, wrapping cells, no vertical rules. Not one pipe and no
    delimiter row reaches the screen. The characters never move — copy still yields the source, search
    still finds the words — they are simply not what is drawn. A Home row, a search result, and
    VoiceOver get the cells too, by the same rule and for the same reason (see Copy, cut & paste).
  - **Column widths come from the words**, not from an equal share. A column of labels and a column of
    prices settles at roughly 70/30 because that is what the cells measure; `Day` holds one digit and
    gets a digit's worth of the screen. A column whose every value is a quantity is right-aligned, so a
    total lines up on its digits (`TableCardLayout`).
  - **A table too wide for the phone is previewed, not crushed**: the first three columns of the first
    three rows, and a line saying what is held back — "9 rows · 7 columns … View Table ›". Tapping it
    opens `TableReaderView`: real columns, a heading row that stays put while the rows travel under it,
    horizontal scrolling, cells that wrap rather than truncate, and VoiceOver that reads each cell with
    the column it belongs to ("Park, Kenai Fjords"). It reads and never writes. The cut-off is whether
    the words fit at this width and text size — never a column count someone picked.
  - **Writing the note, the table is its source.** Taking the keyboard puts every table back into pipe
    rows, under a quiet container; giving it up puts the tables back. A table being edited is text being
    edited, and the caret has to be somewhere the writer can see it (RULES.md §7).
  - **Rejected: re-spacing the source in place.** Laying the pipes out as invisible tab stops and
    painting a hairline over the delimiter row *looked* like rendering and was not: stray closing pipes,
    a banded grey block, columns aligned by spacing, and a caret that could land inside what looked like
    a rendered table. Hiding some characters and repositioning others is not a presentation
    (2026-08-21).
  - **A one-column table is just its cells**, one per line. There is no grid to draw.
  - **Known limitation:** a cell whose source held several lines arrives as one line of words. Every
    word survives; the line breaks inside that cell do not, because a row is a line and a line cannot
    contain one.
- HTML that carries no structure at all is *declined*, and the system's own plain-text paste runs — the
  shortest path is also the most faithful one.
- The HTML is read by a small tag-level parser rather than `NSAttributedString(documentType: .html)`:
  that importer needs WebKit and the main thread, and it resolves headings down to font sizes, which
  would leave us inferring structure from type size — exactly what must not happen.

**Diagnosing a bad paste on a device.** A debug build launched with `-logPasteFlavors` prints, on every
paste, which pasteboard types the source offered, tag and flavor counts for the HTML and Markdown it
carried, what each reader made of it, and which flavor won. Counts only — never a character of the
content (`RULES.md` §3). It exists to answer the one question a screenshot cannot: when an assistant's
answer pastes badly, *which representation did As Told actually get?*

### Acceptance

- A user can write a 2,000+ word draft comfortably, and a bullet list / numbered list / checklist, in one
  note, without a mode switch — and Home/Editor still feel minimal.
- Copying a checklist into Messages pastes `☐ Call Ravi`. As Told → As Told keeps the checklist exactly,
  through the private pasteboard type; a rich source that states the list around the glyph (HTML `<li>`,
  an `NSTextList`) imports it as a real checklist item. Copying the line back out of a **plain-text**
  app inserts those characters verbatim and is not guaranteed to restore checklist structure — plain
  text is never read for structure (`RULES.md` §4).
- Pasting a page of headings, bullets, and a table from a browser or a chat app lands as headings, real
  bullets, and the table's cells — with not one word of it changed. Pasting the same content as plain
  text lands exactly as plain text.

## Milestone B — Voice structure commands — **shipped in V1**

Extends voice from speech-to-string to **speech-to-document**, on the same document model — no separate
voice-only note system.

**As built** (`Core/Editor/VoiceStructure.swift`). A command is recognized only when all four hold:

1. it is at the **start of the transcript** or after a sentence boundary (`.` `!` `?` newline);
2. it matches one of the nine phrases exactly, case-insensitively;
3. it ends on a **word boundary** — "headings" is not `heading`;
4. it is followed by a terminator or the **end of the transcript**.

Anything else is inserted verbatim. Ordinary speech that merely sounds structured — *"buy milk, and also
eggs, and bread"* — stays one sentence, because inferring a list would be deciding the words meant
something the speaker did not say.

- Small, fixed, deterministic vocabulary: nine *actions* — `new paragraph`, `new line`, `heading`,
  `subheading`, `bullet list`, `numbered list`, `checklist`, `next item`, `end list` — each accepting
  the closed alias set in `RULES.md` §2 (`start bullet list`, `bulleted list`, `start numbered list`,
  `start checklist`, `new item`, `stop list`, `normal paragraph`). `end list` leaves the structure the
  way Return on an empty item does, taking a marker-only item with it rather than stranding it.
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

## Discoverability — **shipped in V1** (2026-08-19)

Typing a marker only helps someone who already knows the syntax, and the nine voice phrases are
unguessable. The first answer to that was three teaching surfaces — an empty-note cheat-sheet, a `?`
reference, and a one-time voice tip — none of which could *apply* anything. That was teaching syntax as
a substitute for a control, and it was the wrong trade: the Style menu (Milestone B2) makes structure
discoverable by being visible, and teaching became optional rather than load-bearing.

| Surface | When | What it does |
|---|---|---|
| Style menu (`Aa`) | only while the **body** has the caret | applies any of the six structures; checks the current one |
| Writing help | inside the Style menu | the full reference: five markers, all nine commands |
| Voice tip | once, after the **first successful** transcription | two examples, near the microphone |

Rules that hold these in place:

- The Style menu follows the same contextual rule as the Done button — present while writing, gone
  while reading — and gates on the *body's* caret specifically. Full behavior in Milestone B2 below.
- **Writing help is reference only and applies no structure.** Applying belongs to the Style menu; a
  second path to it from the sheet would be two formatting systems for one document. `WritingHelp`
  derives all of its content from `BlockKind` and `VoiceStructureParser`, so help cannot drift from
  behavior.
- The voice tip requires a transcription that **actually succeeded and actually left the device**. A
  failure, a cancelled capture, or a declined disclosure leaves it unshown *and* unmarked, so it still has
  its one chance later. This also keeps it from stacking on the consent sheet during a first recording.
- The tip shows two examples, not nine commands. Nine commands out of context teaches nobody; writing
  help is where someone who wants the full list will look.
- **Removed 2026-08-19:** the empty-note marker hint. It existed to make syntax discoverable when syntax
  was the only way in; with the Style menu shipped, it asked a writer to learn something before writing
  their first word. The placeholder is `Start writing…` and nothing else.

### Accepted limitation — search matches markers

`noteMatches` runs over the raw source, so a query containing marker characters can match structure:
`[x]` finds every checked item, `- ` every bullet. Accepted for V1 and deliberately not fixed. It exposes
no markers visually, corrupts no results, and loses no legitimate match — stripping markers before search
would mean maintaining a second projection of every note purely to make a rare query tidier.

## Milestone B2 — the "Style" control — **shipped in V1**

Structure used to be creatable two ways: typing a marker (`- `, `# `, `1. `) and the voice commands.
Converting an *existing* paragraph — "make this a heading" — had no UI path at all, because
`DocumentAction.setBlockKind` was implemented and tested but deliberately had no caller.

That was recorded here as an accepted usability hole. It was not acceptable: typing `- ` to get a
bullet is developer knowledge, and it was the *only* way a person who does not know Markdown could
discover that As Told has structure. Promoted into V1 on 2026-08-19 (`RULES.md` §7).

**As built** (`Core/Editor/BlockStyle.swift`, `Features/Editor/EditorView.swift`,
`Features/Editor/BodyTextView.swift`):

- **One floating writing toolbar** above the keyboard (`WritingToolbar`, moved out of the navigation
  bar 2026-08-20): `Aa` · `•` · `1.` · `☑` · microphone, on a `.thinMaterial` capsule below the note.
  The three list structures apply in one tap; `Aa` (SF Symbol `textformat`, accessibility label
  "Style") holds Paragraph · Heading · Subheading, then a divider, then **Writing help…**.
  - **It reflects the caret.** The button for the block the caret sits in is shown selected, so the bar
    is a quiet indicator of the current structure as well as a way to change it. A selection spanning
    two structures shows none of them selected — it is not any one of them.
  - **Pressing Return out of a list changes what is selected**, immediately, which is how leaving a
    list becomes visible rather than merely felt.
  - **Where it is, and is not:** present while the body has the caret; microphone only while reading;
    absent entirely while the **title** has the keyboard, because structure does not apply to a title
    and voice does not write into one; replaced by the recording panel while recording.
  - **Multi-line selection** converts every line it touches, as one undo step — the same
    `DocumentAction.setBlockKind` call the menu always made. (`Normal` → **Paragraph**, 2026-08-19 — it is the explicit way out
  of a list, so it is named after what you are going back to. Title case and `Bullet list` →
  **Bulleted List**, 2026-08-20 — Apple's wording for these rows. The *spoken* command stays
  "bullet list": a label and a phrase are different jobs, RULES.md §1.) It routes through the existing `setBlockKind` primitive — no second
  formatting path.
- Present only while the **body** has the caret. Not while reading, and not while the title is being
  edited — a title has no block structure, so styling one means nothing.
- **A menu, not a sheet.** A sheet resigns first responder: the keyboard would drop and the selection
  being styled would have to be restored afterwards. The menu leaves the keyboard and the live
  selection intact, which is what makes "select four lines, pick a style" work at all.
- The **current** block is checked. A selection spanning two different structures checks nothing rather
  than claiming to be the first line's style (`BlockStyle.current` returns `nil`).
- Applying a style converts **every line the selection touches**, as **one `TextEdit`** and therefore
  one undo step. A selection ending exactly at the next line's start does not convert that line — it
  took the newline and nothing else.
- **Numbering** continues from the numbered line immediately above the selection and runs in sequence
  across it. Lines outside the selection are never renumbered.
- **A ticked checklist item stays ticked** when Checklist is re-applied, so the menu is safe to tap
  twice — which a checkmark against the current style invites.
- MUST NOT become a persistent `B I U H1 H2 • 1. ☑` ribbon across the editor (RULES.md §1, §4).
  A keyboard-accessory row of style buttons is that ribbon, not an alternative to it.

Nothing else joins this control. Bold and italic are **inline** formatting — selection ranges, nested
formatting, source↔visible mapping for the markers, copy/paste semantics, VoiceOver, behavior across
Telugu/Hindi — which is a different category from the line-level structure here, and stays on the
do-not-build list (`RULES.md` §7).

### What went with it

- The standalone `?` toolbar item, folded into the menu as **Writing help…**. The sheet itself is
  unchanged and still applies nothing.
- The empty note's marker cheat-sheet (`WritingHelp.emptyNoteHintMarkers` / `emptyNoteHintLead`). Its
  only purpose was compensating for the absent control; the placeholder is now `Start writing…` alone.

## Milestone C — Keep at Top (evaluate later)

Broader writing means an unfinished draft/checklist may need to stay visible for several days instead of
scrolling into history. A future, opt-in **Keep at Top** surfaces such a note above the chronological
timeline, with an explicit "Remove from Keeping" that returns it to its natural date position.

- Evaluate **only after** structured writing exists and users actually keep active drafts around.
- NOT folders, favorites, tags, or a workspace. The timeline stays the primary organization model.

## Milestone D — A note can remind you (post-1.0, decided 2026-08-20, unbuilt)

Reminders were on the "not planned" list below until 2026-08-20, when they were reclassified as a
**guarded post-V1 exception**. Full rules and preconditions: `RULES.md` §7, "Post-V1 — note reminders".
Summary of the product shape:

Sometimes something you write needs to come back at the right time. When a writer explicitly asks for
a reminder **in their own words** — typed or spoken — As Told may notice it and offer to schedule one
local notification that opens that exact note. Nothing is scheduled without a tap.

- One-time reminders only. Explicit or relative date/time. Multiple per note.
- Typing and voice converge on one detector; paste does not trigger it.
- Detection is local, deterministic, and conservative — **false positives are worse than false
  negatives**. An ambiguous phrase ("sometime next week", "later") produces no suggestion, and a past-tense
  sentence ("I paid rent yesterday") must never trigger. A time is never invented on the user's behalf.
- The suggestion is ephemeral: it appears, is answered, and leaves. No reminders screen, no chip parked
  in the editor, no task state anywhere.
- English first; Telugu / Hindi / mixed phrasing verified with real speakers before their phrase lists lock.

**Not** a task manager: no tab, dashboard, inbox, projects, priorities, completion, recurrence, snooze,
or calendar sync. Checklists gain nothing from this — a reminder attaches to a note, never to an item.

**Sequencing:** begins only after the V1 release gate (`RULES.md` §8) is complete. Reopening schema
migration, permissions, notification lifecycle, navigation, and deletion semantics during release
validation is how a finished V1 becomes another month of regressions.

---

# Later / explicitly not planned now

- folders
- tags
- collaborative notes
- templates
- tasks
- streaks
- mood tracking
- generative prompts
- AI writing suggestions
- AI summaries
- note chat
- semantic embeddings
- public profiles
- web social feed
