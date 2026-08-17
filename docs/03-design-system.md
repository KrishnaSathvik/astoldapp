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
4. Calendar sheet — month grid with note dots + a "Go to" list (`Today`, most recent note date).
5. Note editor — Light and Dark (`Title` placeholder, `Start writing…`, mic bottom-left/right).
6. Voice recording — inline transcript with real Telugu+English code-switching, dark recording surface
   (waveform, elapsed time, `Cancel` / stop / `Done`).
7. Search — query field, results as title + preview + date, `Cancel`.
8. Swipe to delete — native red `Delete` revealed.
9. Settings — `PRIVACY` (Lock with Face ID) and `ABOUT` (Privacy Policy, About [AppName], Version 1.0.0).
10. Lock screen (Face ID) — mark, wordmark, Face ID glyph, `Unlock`.

### Brand mark & wordmark

- **Mark:** a minimal **feather / quill** glyph, used on Splash, Welcome, and Lock. It appears in a
  soft rounded-square app-tile treatment on Splash, and as a bare glyph on Welcome/Lock.
- **Wordmark:** the word rendered in an **elegant serif** logotype (the reference uses "Yourly" as the
  placeholder brand — see `[AppName]` policy in `README.md`/`CLAUDE.md`).
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
- Settings About row reads `About [AppName]` and `Version 1.0.0`.

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
Editor Search    Calendar Sheet
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

### Suggested copy

**Write it. Say it. Keep it.**

A private place for the thoughts you want to keep.

Type them or speak them. Keep them as they came.

### Layout

- generous top and side whitespace
- one primary button near safe lower region
- no permission controls

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

## 4.6 Calendar sheet

### Presentation

Native sheet.

### Header

- current month/year
- close control where appropriate

### Grid

- native weekday rhythm
- days with notes: tiny dot
- selected date: clear selection
- Today: native distinction

### No

- heatmap
- note-count badge
- streak colors

---

## 4.7 Editor — idle/typing

```text
<                                      ···

AUGUST 17, 2026

Title

Start writing...




                                      [mic]
```

### Rules

- title has no box
- body has no box
- no toolbar
- no Save
- no word count
- keyboard behaves natively
- generous horizontal margins
- date is visually secondary

### Title

Placeholder: `Title`

Do not display the word `optional` unless usability testing proves users are confused.

### Body

Placeholder: `Start writing…`

---

## 4.8 Editor — voice recording

Editor stays visible.

Bottom recording surface expands from the mic control.

Include:

- live audio level/waveform
- elapsed time
- Cancel
- Done

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
About [AppName]                      >
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

## V1

System controlled only.

```swift
// Do not force:
.preferredColorScheme(.light)
.preferredColorScheme(.dark)
```

Let iOS determine appearance.

Custom colors are adaptive assets.

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
