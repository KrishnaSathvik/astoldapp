# UI/UX & Design System

## 0. Visual reference (canonical)

The approved visual reference for V1 is:

`docs/design-reference/screens-overview.png`

It is a 10-screen mockup and is the **canonical target** for look and feel. When pixels and prose
disagree on layout, defer to this reference for visual intent and to the specs/`RULES.md` for behavior.
A per-screen walkthrough lives in `docs/design-reference/README.md`.

### Screens shown

1. Splash — brand mark centered above the wordmark.
2. Welcome (first launch) — mark, wordmark, tagline, short explanation, single `Continue` button.
3. Home — Light and Dark, identical layout.
4. Calendar — month grid with note dots + the selected day's notes beneath it, pushed inside Home's stack.
5. Note editor — Light and Dark (`Title` placeholder, `Start writing…`, mic bottom-left/right).
6. Voice recording — inline transcript with real Telugu+English code-switching, dark recording surface
   (waveform, elapsed time, `Cancel` / stop / `Done`).
7. Search — query field, results as title + preview + date, `Cancel`.
8. Swipe to delete — native red `Delete` revealed.
9. Settings — `PRIVACY` (Lock with Face ID) and `ABOUT` (Privacy Policy, About As Told, Version 1.0.0).
10. Lock screen (Face ID) — mark, wordmark, Face ID glyph, `Unlock`.

### Brand mark & wordmark

- **Mark:** the **feather** glyph, used on Splash, Welcome, Lock, and About. It appears in a
  soft rounded-square app-tile treatment on Splash, and as a bare glyph elsewhere.
  **It is the same artwork as the app icon and the OG card** — one feather across every surface
  (`Core/DesignSystem/FeatherMark.swift`, `Resources/Assets.xcassets/FeatherMark.imageset`), derived
  from `AppIcon.appiconset/icon-1024.png`. It ships as a **template** image: the artwork lives in the
  alpha channel, so the chalky texture and pale rachis are opacity rather than colour, and a single
  asset tints to `Color.ds.accent` and inverts correctly in Dark Mode. The mark is sized by **height**
  (~0.65 as wide); do not re-draw it as a vector path.
- **Wordmark:** the word **As Told** rendered in an **elegant serif** logotype (the reference PNG still
  shows the older "Yourly" wordmark; the locked name is **As Told** — see `README.md` §2).
- **Important — this does not change the "no custom font in V1" rule.** The serif is a **brand
  logotype asset** (mark + wordmark image), used only on Splash / Welcome / Lock. **All UI text**
  (titles, note content, controls, settings) still uses the system San Francisco font with Dynamic
  Type. Do not set a serif as a UI text font.

### What the reference confirms / pins down

- Warm off-white `canvas` in Light and near-black `canvas` in Dark, matching §5.2 tokens.
- Dark navy `accent` used for: the `Continue` button, the floating `+`, and the selected calendar day.
- Home rows are chromeless (no cards) — typography + whitespace + generous vertical rhythm.
- The floating `+` is a filled dark circular control, bottom-right, quiet.
- Calendar selected day is a filled accent circle; days-with-notes carry a small dot; a "Go to" list
  offers `Today` and the most recent note date.
- The voice recording surface is the only place using a dark system-material panel; the writing surface
  stays solid (see §10).
- Settings About row reads `About As Told` and `Version 1.0.0`.

---

## 1. Design direction

### Name

**Quiet Editorial**

### Desired feeling

- private
- calm
- intentional
- native
- warm
- precise
- premium without decoration

### Avoid

- SaaS dashboard aesthetics
- excessive cards
- generic glassmorphism
- bright gradients
- AI sparkle icons
- emoji controls
- heavy shadows
- colorful category systems
- oversized floating controls
- decorative animation that slows capture

---

## 2. Core UX rules

1. The note is more important than the interface.
2. Never require Save.
3. Never require organization before capture.
4. Never ask a permission before the user invokes the feature.
5. Prefer inline interactions over extra screens.
6. Prefer native iOS controls when they already solve the interaction.
7. Voice and typing are the same note.
8. Deletion should be reversible for a short period.
9. No user-facing pagination.
10. No interface copy that judges, encourages, gamifies, or diagnoses the user.
11. No time-of-day greeting.
12. Do not show creation time on normal Home rows.
13. Follow the system Light/Dark setting automatically.

---

# 3. Navigation model

```text
Welcome (first launch only)
        ↓
       Home
   ┌────┼───────────┐
   │    │           │
Editor Search    Calendar
   │
 Voice
   │
Settings / App Lock
```

Do not add a tab bar in V1.

There are not enough top-level destinations to justify one.

---

# 4. Screen specifications

## 4.1 Native launch screen

### Layout

Centered app mark and/or app name.

### Rules

- no button
- no fake loading progress
- no complex animation
- match first rendered background to reduce flash

---

## 4.2 Welcome

### Hierarchy

1. app mark
2. app name
3. tagline
4. short explanation
5. Continue

### Copy

**Write it. Say it. Keep it.**

A quiet place for anything you want to put into words.

Exactly these two lines. The earlier third line ("Write it, say it, shape it your way.") restated the
tagline and is gone — the tagline already says it, and repeating it is what made the screen read as a
placeholder.

### Layout

Three blocks: brand, message, action.

- Brand: feather at 76 pt + serif wordmark (`AppMark(markSize: 76)`).
- Message: 24 pt below the brand block, 12 pt between its two lines, capped at 240 pt wide so the
  supporting sentence breaks over two even lines rather than a ragged three.
- Action: one primary button, pinned by `safeAreaInset(edge: .bottom)` — which also lifts the optical
  centre of the brand + message above the centre of the screen. 24 pt side and vertical padding,
  54 pt tall, `DSRadius.large`. Built with `Spacer()`s, never hard-coded vertical offsets, so it
  holds from SE to Max.
- Side margin 24 pt (wider than Home's 20 pt — this screen is a card, not a list).
- The filled button's label is `Color.ds.onAccent`, **not** `.white`: the Dark Mode accent (`#8AA9BE`)
  is light enough that white on it lands at 2.5:1 and reads as a *disabled* control. `onAccent` takes
  the same fill to 7.6:1 (8.8:1 in Light).
- Press feedback is a 0.98 scale, not the system label fade — on a filled button that fade also reads
  as switched off.
- No permission controls, and no navigation chrome: Welcome is a bare root view in `AppRootView`,
  never pushed, so there is no back affordance.

---

## 4.3 Home — populated

### Top region

Small date:

`AUGUST 17, 2026`

Primary title:

`Today`

Calendar action aligned opposite title.

### Content

Continuous vertical timeline.

Example:

```text
AUGUST 17, 2026

Today                                  [calendar]

Alaska trip idea
I keep thinking maybe instead of staying
the entire week in Anchorage we could...

Something I remembered
Need to call them tomorrow and ask...

I don't know why but today I suddenly
started thinking about...

Yesterday

Random thoughts at night
It's weird how some songs take you...

August 15

Work ideas
New project direction looks promising...
```

### Note row

No card by default.

Use:

- typography
- whitespace
- optional subtle separator

Prefer `VStack` rhythm over rounded rectangles.

Hierarchy — restrained, editorial, never a settings list:

| | Titled note | Untitled note |
|---|---|---|
| Primary | title, `body` semibold (~17 pt), 1 line | first meaningful body line, `body` regular (~17 pt), primary colour |
| Secondary | body preview, `subheadline` (~15 pt), secondary colour, 2–3 lines | — |

Both previews carry a little extra line spacing. Leading blank lines are skipped so the preview
always starts on real words. The row never renders `Untitled`, and never shows a creation time.

### New note control

Bottom-right, reachable, visually quiet.

Use SF Symbol `plus`.

Target hit area: at least 44×44 pt.

Visual shape can use a native material/control treatment.

---

## 4.4 Home — empty

Do not use a giant illustration.

Preferred:

```text
AUGUST 17, 2026

Today

Your thoughts will appear here.

                                      [+]
```

Optional alternate supporting copy:

`Write something. Say something.`

Do not repeat the complete marketing pitch.

---

## 4.5 Search state

Prefer native `.searchable` behavior that can appear via pull-down/activation.

Result:

```text
[ Search notes: Alaska                         ]

Alaska trip idea
I keep thinking maybe instead...
August 17, 2026

Something about flights
Maybe Alaska next summer...
August 12, 2026
```

Dates are useful in search even though they are omitted from normal Home rows.

---

## 4.6 Calendar

### Presentation

Pushed inside Home's navigation stack, not a sheet. _(Changed 2026-08-19: the spec said sheet, the
push shipped. It carries the system back button, so the screen needs no close control and no second
way out — the reason there is also no "Go to Today" button on it.)_

### Header

- current month/year
- month step controls (previous / next)

### Grid

- native weekday rhythm
- days with notes: tiny dot
- selected date: clear selection (the selection replaces that day's dot — its notes are listed below)
- Today: native distinction
- opens with today selected; stepping months selects today when it is in view, else the 1st

### Selected day

Beneath the grid: the day label (`Today` / `Yesterday` / `August 15`) and that day's notes, using the
same `NoteRow` as Home. Tapping one opens it **from here**, so Back returns to the calendar with the
day still selected. A day with nothing on it reads `Nothing written on this day.`

This list is a way *to* a note, not a place to browse. It has no search, no sort, no grouping, no
pagination, and no counts — see RULES.md §1. Swipe-to-delete is deliberately not offered here; the
note's own overflow (`···` → Delete Note) covers it, and the Undo banner appears on this screen.

### No

- heatmap
- note-count badge
- streak colors
- a second search field

---

## 4.7 Editor — idle/typing

```text
<                                   Aa

AUGUST 17, 2026

Title

Start writing...




                                      [mic]
```

### Rules

- title has no box
- body has no box
- no bar above the page — the writing controls float below it, above the keyboard (RULES.md §1, §4)
- no Save
- no word count
- keyboard behaves natively
- generous horizontal margins
- date is visually secondary
- body uses generous line spacing — the screen must be comfortable to *read*, not only to fill in

### Reading vs editing

The same screen serves both; only the arriving focus differs.

| | New note | Existing note |
|---|---|---|
| On open | body focused, keyboard up | reading — nothing focused, no keyboard |
| Trailing toolbar | nothing | nothing |
| Floating writing toolbar | `Aa` · `•` · `1.` · `☑` · mic | mic only |
| Starting to edit | already editing | tap title or body; caret lands where tapped |

A new note takes focus **after the push finishes**, never during it. Focus taken mid-transition puts
the keyboard on a view that is still sliding, so it travels sideways into the screen with the editor
instead of rising from the bottom once the editor has arrived — in Light mode, a grey panel sweeping
in from the right edge. The wait is on the navigation transition coordinator, not a delay
(`NotePageView.afterNavigationTransition`, 2026-08-20).

`Aa` shows only when the **body** has the caret. Editing the title shows no trailing chrome at all —
a title has no block structure, so offering to style it would be offering something that does
nothing.

No `Read Mode` / `Edit Mode` toggle, no custom "Hide Keyboard" bar, and **no `Done`**. The keyboard
leaves by scrolling the body interactively or by navigating Back. There is no completion control at
all: autosave already saved, and a button that ends editing teaches people that not pressing it
loses work — which is exactly what happened before it was removed (2026-08-19).

### Rows and drafts

Home, Search, and the calendar never render a note with nothing in it. An editor may hold an
effectively empty draft — that is what keeps a note from being destroyed by a temporary scene
transition — but such a draft is not a row. Home used to draw one as a zero-height row whose
separator survived as a stray line under `Today` for the moment between leaving an untouched New
Note and the deletion propagating. The rule lives in `Note.isUserVisible` (RULES.md §4).

### Scrolling

The note is one page and it scrolls as one. Date, title, and body live inside a single scroll view
(`NotePageView`), so the date and title scroll away with the text instead of staying pinned to the top
of the screen. Nothing in the editor shows a scroll indicator — a note is a page that flows, not a
document with a measuring stick down its side.

Both were fixed on 2026-08-20. Before it, the body was the only thing that scrolled: a long note ran
on underneath a fixed date and title and was clipped mid-line against them, and the body drew UIKit's
default scrollbar while every other surface in the app hides one.

### Title

Placeholder: `Title`

Do not display the word `optional` unless usability testing proves users are confused.

### Body

Placeholder: `Start writing…`, and nothing under it. (An empty note carried a three-marker syntax hint
until 2026-08-19; it went with the arrival of the Style menu, which made the syntax optional knowledge
rather than the price of entry.)

### Style menu (`Aa`)

One toolbar item, SF Symbol `textformat`, accessibility label "Style". Shown only while the body
has the caret. Opens a menu — never a sheet, because a sheet resigns first responder and would drop
both the keyboard and the selection being styled.

```
Style
  Paragraph
  Heading
✓ Bulleted List
  Numbered List
  Checklist
  ─────────────
  Writing help…
```

- The current block is checked. A selection spanning two different structures checks nothing.
- Picking a structure converts every line the selection touches, in one undo step.
- **Paragraph** is the explicit way out of a list, alongside the fast one (Return on an empty item).
  Either way the caret is drawn at the paragraph inset immediately, before anything else is typed.
- Rows are **title case**, Apple's wording for these ("Bulleted List", not "Bullet list"). The label
  is not the voice command: you still *say* "bullet list" (RULES.md §1). Every surface reads the label
  from `BlockStyle.name`, so the menu and the writing-help sheet cannot disagree.
- Six structures and the help row. Nothing else joins it — inline formatting (bold, italic, colors,
  alignment) is full rich text and stays on the do-not-build list (RULES.md §7).

### How structure renders (`Core/Editor/StructuredTextRendering.swift`)

Source markers (`# `, `- `, `1. `, `- [ ] `) stay in `body` and are hidden at the glyph layer; the
visible bullet, number, and checkbox are drawn in a 28pt left gutter.

**A checkbox's target is wider and taller than its gutter** (`StructuredTextStyle.checkboxHitWidth`
and `checkboxHitHeight`, 44pt each, 2026-08-21). The box stays small — a marker is not the sentence —
but the region that ticks it has to clear the 44pt floor below, and ticking items off is the whole
point of a checklist. The overhang past the gutter covers roughly the item's first character, and only
a checklist line claims it.

Height is the harder half, and it is settled in the *layout* rather than in the hit test. **A checklist
row is 44pt tall** (`StructuredTextStyle.checklistLeading`, 2026-08-21): the extra leading over a line
of body type is split evenly above and below, so the words stay centred in their row and a run of items
keeps an even rhythm. It is derived from the body line height, so it tracks Dynamic Type and falls to
zero on its own at the text sizes where a line already clears 44pt.

No hit test could have done this. A middle item's target is its own line — two adjacent controls cannot
both hold 44pt of exclusive space at a 24pt pitch, and every attempt to overlap them either steals
touches from a neighbour or collapses back to the line height. Measured: every item in a run now gets
exactly 44.0pt, and paragraphs, bullets, and numbered items are untouched at 24.3pt. A checkbox is a
control and takes what §4 asks for; the rest of the page is prose, which does not —
`onlyChecklistLinesCarryTheExtraLeading` holds that line.

The hit test still bounds the target and still grows it where the row is somehow short, in
`BodyTextView.Coordinator.checkboxLine(in:at:)`, by two rules:

1. **A touch inside an item's own line is that item's.** Lines never overlap, so a stack of adjacent
   items cannot steal from each other: the item you touched is the item that ticks.
2. **Anywhere else the nearest item wins**, measured to the edge of its line, ties to the earlier one.
   A band may take at most half of a neighbouring line that is *not* a checklist item, so the
   paragraph under a checklist keeps the half its own words sit in and stays tappable for a caret.

Bounding it was itself a fix: the previous hit test resolved *every* point above the text to the first
line, so a tap on the note's date row ticked the first item of the note
(`aTouchInThePagesHeaderSpaceIsNotAToggle`, 2026-08-21).

**VoiceOver can work a checklist, not only hear one** (`StructuredTextView.accessibilityCustomActions`,
2026-08-21). Each item carries an action of its own, named with the words the reader sees — "Check Call
Ravi", "Uncheck Book hotel" — because a note being read has no caret for a cursor-relative action to
act on. Activating one makes the same `DocumentAction.toggleChecklistEdit` a tap on the gutter makes,
through the same edit primitive: one undo step, the caret left where it was, and no second
implementation to drift. The new state is announced in the note's own words ("Checked, Call Ravi").

**VoiceOver is told the state, not the glyph** (`StructuredTextExport.spokenText`, 2026-08-21). The
body's accessibility value used to be the note with every marker stripped, so `☐ Call Ravi` and
`☑ Call Ravi` read identically and a bullet read as a paragraph — state carried by a drawn mark and
nothing else, which the Color rule below forbids. Each item now names itself: "Bullet, Eggs",
"Unchecked, Call Ravi", "Checked, Book hotel". A number reads as its own ordinal, a heading as its
words, and a table as its cells rather than the pipes it is stored in.

| Role | Type |
|---|---|
| Heading (`# `) | `.title2` semibold |
| Subheading (`## `) | `.headline` — body size, heavier |
| Body, list items | `.body` |
| Bullet / number / checkbox marker | `.body` — the line's own font, `TextSecondary` |

- Size carries *heading*, weight carries *subheading*. Two large sizes two points apart at the same
  weight read as one structure, which makes the choice between them meaningless.
- A heading and a subheading get space **above** them (0.75 / 0.55 of the body line height, so it
  tracks Dynamic Type), never on the first line. A section break has to be visible as a break.
- Drawn gutter markers align to the text **baseline**, not to the middle of the line fragment — the
  fragment carries the paragraph's line spacing underneath the text, so a centred marker rides low.
- **A marker is one colour: `TextSecondary`.** Bullet, number, and the outline of an unticked box all
  use the semantic secondary token — quieter than the sentence, never faint. No custom alphas: the
  number was drawn at 70% of the body colour and the empty box at 55%, which put the box at 3.75:1 on
  Light canvas, below the 4.5:1 §6 requires of every glyph, and 5.7:1 in Dark. Secondary is 6.3:1
  Light / 8.5:1 Dark. A ticked box is the only marker drawn in `Accent` — the tick is a *state*, and
  it is the one thing in the gutter worth looking at.
- **Weak markers read as small markers.** The complaint that list type "looks smaller" than prose was
  measured and is false — a list line is the same 17pt body (see below). What was actually wrong was
  contrast. Fix a faint marker with colour; **never** by enlarging it independently of the line, which
  breaks the one-definition rule below and desynchronises the gutter from Dynamic Type.
- **List items are body text.** A bullet, numbered, or checklist line uses exactly the paragraph font,
  line height, and Dynamic Type scaling — only the gutter marker differs, and it is drawn in the same
  font as the line beside it. There is one definition of a line's type,
  `StructuredTextStyle.attributes(for:)`, and the styler, the typing attributes, and the drawn marker
  all read it. A second copy is how list rows end up a size smaller than the prose around them.
- **An empty line is styled through its terminating newline, and the empty *last* line through the
  text view's typing attributes.** An empty line has no characters to carry attributes; the final one
  has no newline either, so TextKit lays it out from `typingAttributes`. Leaving those describing the
  previous line is what once left the caret sitting in the list gutter after a writer had left the
  list — a correct document, drawn wrong. Guarded by `Tests/YourlyTests/StructuredCaretTests.swift`.
- Marker glyphs are hidden with **zero advancement**, never by being nulled. A null glyph is ignored
  during layout, which collapses any line holding nothing but its marker — the line Return creates,
  and the line the Style menu styles on a blank row. Guarded by `Tests/YourlyTests/StructuredLayoutTests.swift`.

---

## 4.8 Editor — voice recording

Editor stays visible.

Bottom recording surface expands from the mic control.

Include, and only these:

- live audio level/waveform
- elapsed time
- Cancel (leading, quiet)
- Done (centre, primary circular control, labelled)

Two controls, not three. `Stop` and `Done` would trigger the identical transition — there is no
review-before-transcribe step to separate them — so the panel offers one way to end the recording
and one way to abandon it. Haptics mark start, stop, success, and failure.

The recording control can use system material/Liquid Glass treatment.

The writing surface should remain solid.

---

## 4.9 Editor — transcribing

After Done:

- recording UI collapses
- show small `Transcribing…` state
- preserve insertion anchor
- prevent conflicting edit behavior only as much as required for deterministic insertion
- insert returned text
- resume normal editing

Avoid a modal transcript preview.

---

## 4.10 Swipe delete

Use native destructive swipe styling.

After delete:

`Note deleted                    Undo`

Keep feedback small and temporary.

---

## 4.11 Settings

```text
Settings

PRIVACY

Lock with Face ID                  [toggle]


ABOUT

Privacy                              >
About As Told                      >
Version 1.0.0
```

No appearance setting in V1 because appearance follows system.

---

## 4.12 Locked state

Keep minimal.

- app mark
- app name
- system authentication
- optional Unlock action if system flow was canceled

Do not show blurred readable note text behind it.

---

# 5. Color system

## 5.1 Implementation rule

Use **semantic tokens**, not direct color names in feature code.

Good:

- `Color.ds.canvas`
- `Color.ds.textPrimary`
- `Color.ds.textSecondary`

Avoid:

- `Color(hex: "#F8F7F4")` scattered across views
- `gray500`
- `darkGray`

Use adaptive Asset Catalog colors or dynamic system colors.

## 5.2 Reference palette

These are visual references, not a reason to ignore accessibility/system behavior.

| Token | Light | Dark |
|---|---|---|
| `canvas` | `#F8F7F3` | `#101112` |
| `surfaceElevated` | `#FFFFFF` | `#1A1B1D` |
| `textPrimary` | `#1C1C1E` | `#F3F2EE` |
| `textSecondary` | `#68686D` | `#A6A6AB` |
| `textTertiary` | `#99999F` | `#747479` |
| `separator` | `rgba(60,60,67,0.12)` | `rgba(84,84,88,0.32)` |
| `accent` | `#314D63` | `#8AA9BE` |
| `destructive` | iOS system red | iOS system red |

### Native semantic preference

Where native colors provide better behavior, prefer:

- `Color.primary`
- `Color.secondary`
- system red
- system materials
- system separator semantics

The warm canvas/accent should be custom adaptive tokens.

---

# 6. Typography

## 6.1 Font family

System San Francisco / SwiftUI system typography.

Do not introduce a custom font in V1.

## 6.2 Type roles

Use Dynamic Type-backed semantic styles.

| Token | Reference | Usage |
|---|---|---|
| `homeTitle` | ~34 pt Bold | Today |
| `screenTitle` | ~28 pt Bold | Settings |
| `groupTitle` | ~20 pt Semibold | Yesterday / older date group |
| `noteTitle` | ~17–18 pt Semibold | Home result title |
| `editorTitle` | ~22–24 pt Semibold | Optional note title |
| `editorBody` | ~17–18 pt Regular | Main writing |
| `preview` | ~15 pt Regular | Home body preview |
| `dateLabel` | ~12–13 pt Semibold | top date |
| `caption` | ~12 pt Regular | low-level metadata |

### Editor line rhythm

Target visual line height around 1.35–1.45× font size.

Use readable paragraph spacing; do not compress the body to fit more content.

### Date label

Small uppercase is acceptable if legibility remains good.

Do not manually letter-space aggressively.

---

# 7. Spacing tokens

4-point foundation.

```text
space.1  = 4
space.2  = 8
space.3  = 12
space.4  = 16
space.5  = 20
space.6  = 24
space.8  = 32
space.10 = 40
space.12 = 48
space.16 = 64
```

### Screen margin

Default horizontal content margin:

- 20 pt Home
- test 20–24 pt Editor depending on device width

### Vertical rhythm

Prefer larger gaps between conceptual note entries over visible container chrome.

---

# 8. Radius tokens

Use only where controls/sheets require shape.

```text
radius.small  = 8
radius.medium = 12
radius.large  = 18
radius.xl     = 24
radius.pill   = capsule
```

Do not wrap every note in `radius.large`.

---

# 9. Iconography

Use SF Symbols for system actions.

Preferred symbol families:

- `plus`
- `mic`
- `calendar`
- `magnifyingglass`
- `ellipsis`
- `chevron.left`
- `trash`
- `xmark`
- `checkmark`
- `faceid`
- `lock`

### Rules

- no emoji
- no Font Awesome
- no mixed icon libraries
- symbols should inherit appropriate text/control weight
- interactive icons have >= 44×44 pt hit region even if glyph is smaller

---

# 10. Materials / Liquid Glass

Use modern system material for **controls and navigation**, not content.

Good candidates:

- New Note control
- mic control
- expanded recording surface
- sheet/nav controls

Do not:

- place every note inside a glass card
- put the entire editor on glass
- layer multiple decorative glass surfaces

The content plane should remain calm and opaque.

---

# 11. Shadows

Default: none.

If needed for a floating control:

- extremely subtle
- system-like
- only enough to separate from content

Depth should come primarily from material, hierarchy, and motion.

---

# 12. Motion

Do not hardcode web-style animation timing everywhere. Prefer SwiftUI transitions/springs.

Reference categories:

| Token | Feel | Use |
|---|---|---|
| `motion.fast` | ~150–180 ms | opacity/control state |
| `motion.standard` | ~220–280 ms | small transitions |
| `motion.spring` | native spring | mic expansion, sheet-like transforms |

### Reduce Motion

Respect user preference.

Replace large movement with opacity/state changes where appropriate.

---

# 13. Haptics

Use selectively.

| Event | Feedback |
|---|---|
| Mic start | light |
| Mic Done | light/soft |
| Delete | light |
| Successful significant state | subtle |
| Error | notification/error |
| Every normal tap | none |

SwiftUI sensory feedback is preferred where deployment target supports it.

---

# 14. Accessibility

Required from first implementation.

### Automated audit (enforced)

UI tests run Apple's `performAccessibilityAudit` on Home and Profile, scoped to **hit-region size**
and **sufficient element descriptions** — both must pass. Note rows, search results, and date headers
carry explicit VoiceOver labels/traits; decorative elements (separators, spacers, the avatar disc) are
`accessibilityHidden`. Contrast and Dynamic-Type audits are logged but not gated: the muted
secondary/tertiary greys are a deliberate "Quiet Editorial" choice (tuned darker for readability), and
some contrast flags come from text scrolling under the translucent search bar.

### Dynamic Type

- all text scales
- editor remains usable at accessibility sizes
- controls do not overlap

### VoiceOver

Every icon action has a clear label:

- `New note`
- `Start recording`
- `Stop recording`
- `Open calendar`
- `Delete note`

### Contrast

Review both themes.

### Touch targets

At least ~44×44 pt for primary controls.

### Reduce Motion

Supported.

### Color

Never use only a dot color/state without another accessible label/trait when state must be understood.

---

# 15. Theme behavior

## Table card (reading a note)

A table that arrived by paste is *read* as a table and *written* as its source. The card is the reading
half — see `docs/02-features.md` and RULES.md §7.

Editorial, not spreadsheet. The point of reference is a table set in a book, not a grid in a
spreadsheet: what separates two columns is the space between them.

| Element | Treatment |
|---|---|
| Container | `SurfaceElevated`, 12 pt corner radius, hairline border at `TextTertiary` 35% |
| Heading row | body size / semibold, `TextPrimary`, over a `TextPrimary` 4.5% tint |
| Rule under headings | one hairline, full card width |
| Rows | body size, `TextPrimary`, hairline separators between rows — **no zebra striping** |
| Vertical rules | none, ever |
| Cell padding | 10 pt vertical, 14 pt from the card edge, 14 pt between columns |
| Column widths | measured from the cells, slack shared in the same proportion — never equal shares |
| Alignment | left, except a column whose every value is a quantity, which is right-aligned |
| Wrapping | cells wrap; only a *preview* truncates, and only because the full grid is one tap away |
| Preview footer | footnote, "9 rows · 7 columns" at `TextSecondary`, "View Table ›" at `Accent` |
| Air around the card | 10 pt above and below, inside the space the note reserves for it |

Never on the card: pipes, a delimiter row, a caret, sorting, resizing, or any control at all. A card that
can be typed into has become the spreadsheet RULES.md §7 excludes.

## User-selectable (Profile → Settings → Theme)

Appearance is chosen by the user: **Light / Dark / Use device settings** (default). The choice is
persisted (`ThemeStore`) and applied at the app root via `preferredColorScheme(theme.colorScheme)`
(`nil` for "Use device settings", so iOS still decides in that mode).

```swift
// Applied once, at the app root, driven by the user's Theme choice:
.preferredColorScheme(themeStore.colorScheme)   // .light / .dark / nil
```

Do not scatter `.preferredColorScheme` inside feature views — the root owns it.

Custom colors are adaptive assets (Light + Dark values).

### Testing matrix

Every major screen:

- Light
- Dark
- Light + large type
- Dark + large type
- Reduce Motion
- VoiceOver pass

---

# 16. Component inventory

Keep components small.

```text
AppMark
PrimaryButton
FloatingNewNoteButton
NoteRow
DateGroupHeader
CalendarButton
EditorDateLabel
PlainTitleField
PlainBodyEditor
VoiceButton
RecordingControl
TranscribingIndicator
UndoBanner
SettingsRow
PrivacyCover
LockView
```

Avoid building a large generic component library before screens exist.

---

# 17. Premium quality checklist

A screen is not complete merely because it matches a mockup.

Review:

- Is any element unnecessary?
- Does spacing feel intentional?
- Are controls aligned to optical rather than arbitrary geometry?
- Does Dark Mode feel authored?
- Does keyboard appearance feel native?
- Do transitions preserve context?
- Does haptic feedback add information?
- Can the core action happen immediately?
- Does the screen still work at large text sizes?
- Are there any fake emojis or inconsistent icons?
- Are we using a card simply because it was easy?
- Does the interface disappear once the user starts writing?
