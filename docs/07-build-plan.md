# Build Plan

## Goal

Build the product in vertical slices so a working, beautiful notes app exists before external voice infrastructure is introduced.

Do not spend the first week building transcription/backend while Home and Editor do not exist.

---

# Phase 0 — Project foundation

## Tasks

- create Xcode project
- set iOS deployment target
- SwiftUI app lifecycle
- create folder/module structure
- add SwiftData model container
- add adaptive color assets
- add app icon placeholders
- create design token primitives
- configure `.xcstrings`
- create unit/UI test targets

## Done when

- app launches
- Light/Dark automatically follow system
- design tokens render in Preview
- SwiftData container initializes

---

# Phase 1 — First-run and Home shell

## Build

- launch screen
- Welcome
- persisted `hasCompletedWelcome`
- Home header
- current date
- Today title
- Calendar button placeholder
- New Note button
- empty state

## Done when

Fresh install:

```text
Launch → Welcome → Continue → Empty Home
```

Relaunch:

```text
Launch → Home
```

No permission prompts occur.

---

# Phase 2 — Note model + editor

## Build

- `Note`
- create draft
- editor navigation
- optional title
- body TextEditor
- date label
- body autofocus
- autosave coordinator
- empty draft cleanup
- edit existing note

## Tests

- title optional
- whitespace-only title normalizes
- empty draft disappears
- text survives relaunch
- old note edit does not change creation-day group

## Done when

Typing is a complete usable product loop.

---

# Phase 3 — Home timeline

## Build

- fetch latest notes
- note row
- title/body preview behavior
- date grouping
- Today/Yesterday labels
- older dates
- continuous lazy loading
- no visible pagination

## Seed test

Generate 500–1,000 notes for performance review.

## Done when

Home feels stable and visually premium with:

- 0 notes
- 1 note
- multiple notes today
- multiple days
- long titles
- no titles
- long bodies
- large Dynamic Type

---

# Phase 4 — Delete + Undo

## Build

- native swipe
- soft delete
- Undo feedback
- cleanup expired deletes

## Tests

- undo exact restoration
- app relaunch cleanup
- deleting last note in a group removes empty group cleanly

---

# Phase 5 — Search

## Build

- native `.searchable`
- title/body matching
- result excerpt
- result date
- open result

## Test data

- English
- Telugu Unicode
- Hindi Unicode
- mixed text
- 10k generated notes performance benchmark

## Decision gate

If SwiftData search is fast enough: keep it.

If not: implement an FTS search engine behind `NoteStore`.

Do not optimize before measuring.

---

# Phase 6 — Calendar

## Build

- calendar sheet
- month navigation
- note-day dots
- selected date
- Home date navigation/filter
- Return to Today

## Tests

- month rollover
- year rollover
- timezone
- DST
- day with no notes
- many notes same day

---

# Phase 7 — Settings + privacy lock

## Build

- Settings screen
- Face ID toggle
- `LocalAuthentication`
- privacy cover on inactive/background
- locked root state
- fallback behavior
- About/version rows

## Tests

- enable success
- enable cancel
- biometric failure
- app background
- app switcher snapshot
- foreground
- system permission interruption

---

# Phase 8 — Audio capture UX

Do this before OpenAI integration.

## Build

- microphone permission
- record
- waveform/level
- timer
- Cancel
- Done
- temp file lifecycle
- haptics
- recording state machine

## Local fake transcription service

During UI work, return deterministic fake transcript after a small async delay.

This lets the entire voice UI be perfected without backend dependency.

## Done when

The interaction feels right using a fake service.

---

# Phase 9 — Transcription backend

## Build service

- Node.js 24 LTS
- TypeScript
- Fastify
- `/health`
- `/v1/transcriptions`
- size/type validation
- duration validation (measured from the container, before the paid call)
- OpenAI `gpt-4o-transcribe` (`gpt-transcribe` is a benchmark candidate, not the shipping model)
- content-safe logging
- timeouts
- typed error response
- staging environment

## Security

- API key server-side
- App Attest integration
- rate limiting
- request IDs

## Done when

A real iPhone recording round-trips through staging and returns only transcript text + safe metadata.

---

# Phase 10 — Real transcription integration

## Client

- real `TranscriptionService`
- upload
- loading state
- cancellation behavior
- retry/discard
- cursor anchor insertion
- audio cleanup

## Tests

- airplane mode
- slow network
- server 500
- rate limit
- timeout
- empty result
- user cancels
- app backgrounds mid-request

---

# Phase 11 — Language quality program

This is a release feature, not "QA later."

## Corpus

Create consented test recordings covering:

- English
- Indian English
- Telugu
- Hindi
- Telugu+English
- Hindi+English
- names
- places
- slang
- fast speech
- quiet speech
- background noise
- repetitions/fillers
- numbers

## Compare configurations

- no language hint
- expected multi-language hints
- static verbatim prompt
- prompt variants

Do not add a text-cleanup model.

## Release gate

Pick configuration from measured results.

---

# Phase 12 — Premium polish

Review every screen.

## Visual

- exact margins
- type hierarchy
- Dark Mode
- separators
- materials
- empty states
- long text
- keyboard states

## Interaction

- haptics
- animation
- swipe
- sheet
- mic transform
- transitions

## Accessibility

- VoiceOver
- Dynamic Type
- Reduce Motion
- touch sizes
- contrast

## Performance

- launch
- timeline scroll
- editor typing
- search
- memory during recording

---

# Phase 13 — Privacy / App Store readiness

## Verify

- privacy policy matches actual architecture
- microphone purpose string
- Face ID purpose string
- no content logging
- no embedded OpenAI secret
- temp audio deletion
- app switcher cover
- data collection declaration
- backend retention behavior
- crash logs contain no note text

## App Store materials

- icon
- screenshots
- subtitle
- description
- privacy labels
- TestFlight notes

---

# Verification suite

The canonical run. Everything below must be green before a release build, and the counts are the
known-good baseline — anything lower means something was lost, not that the baseline moved.

```bash
xcodegen generate   # the .xcodeproj is generated and gitignored; regenerate after adding files

# 380 unit tests
xcodebuild test -project Yourly.xcodeproj -scheme Yourly \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:YourlyTests

# 41 UI tests, including the three accessibility audits
xcodebuild test -project Yourly.xcodeproj -scheme Yourly \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:YourlyUITests -parallel-testing-enabled NO

# Release build (drop CODE_SIGNING_ALLOWED=NO once signing is configured)
xcodebuild build -project Yourly.xcodeproj -scheme Yourly \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

# Relay: 84 tests, clean typecheck
cd transcription-service && npx vitest run && npx tsc --noEmit
```

## The UI suite flakes — reproduce before believing it

A whole-suite UI run fails occasionally in a way that reads exactly like a navigation regression:
`Back to notes` never appears, `Calendar should push` times out, several classes fail at once.
Observed 2026-08-19 — one run produced 8 such failures, and **every one of them passed when re-run
in isolation**; three later full runs passed 33/33.

So: a UI failure is not a regression until it reproduces under `-only-testing:` for that single
class or test. Check that before touching product code.

`-parallel-testing-enabled NO` is in the command above as a guard, not as the fix. The generated
scheme already sets `parallelizable = "NO"` on both bundles and a default run creates no clone
simulators (verified by polling `xcrun simctl list devices` mid-run), so the flag currently changes
nothing — it only keeps the canonical command correct if that scheme setting is ever changed. The
cause of the flaky run has not been identified.

---

# Definition of Done — V1

The build is V1-complete only when:

### Capture

- typing works reliably
- title is optional
- autosave is invisible
- empty drafts do not accumulate

### Browse

- Home contains all notes
- grouping is correct
- older notes lazy-load
- calendar works
- search works

### Voice

- record/cancel/done are polished
- API key is server-side
- audio is not retained after success
- retry is safe
- language benchmarks pass agreed thresholds
- no intentional rewriting/translation

### Privacy

- no account
- Face ID lock works
- app-switcher content is protected when lock is enabled
- server does not store content
- logs are content-free

### Design

- Light/Dark are both intentional
- system appearance drives theme
- SF Symbols only for system icons
- no visible formatting toolbar — the `Aa` Style menu is one contextual item, not a bar
- no card-heavy redesign
- Dynamic Type/VoiceOver pass

---

# First coding ticket

Start here:

## `APP-001 — Create native project foundation`

### Acceptance criteria

- SwiftUI iOS project created
- minimum deployment target decided/configured
- SwiftData model container wired
- `AppRootView` routes Welcome/Home
- `hasCompletedWelcome` persists locally
- adaptive `Canvas` and `Accent` colors exist
- spacing tokens exist
- SF Symbols used for placeholder calendar/plus icons
- system Light/Dark changes update the app automatically
- no third-party dependency added

Then:

`APP-002 — Build Welcome`

Then:

`APP-003 — Build Home empty state`

Then:

`APP-004 — Add Note model and Editor`

That is the correct place to start.
