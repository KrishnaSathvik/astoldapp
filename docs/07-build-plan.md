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
- old note edit does not change which period group the note sits in (sorting is by `createdAt`)

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

# 1359 unit tests (measured 2026-08-31 — Home library redesign and its three refinement
# passes, recorder lifecycle, attestation repair; see RULES.md §8)
xcodebuild test -project Yourly.xcodeproj -scheme Yourly \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:YourlyTests

# 101 UI tests, including the three accessibility audits.
# Shut every simulator down first (`xcrun simctl shutdown all`) and use an isolated
# -derivedDataPath: several of these are load-sensitive and fail under contention while passing
# alone, which reads as a regression and is not one.
xcodebuild test -project Yourly.xcodeproj -scheme Yourly \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:YourlyUITests -parallel-testing-enabled NO

# Release build (drop CODE_SIGNING_ALLOWED=NO once signing is configured)
xcodebuild build -project Yourly.xcodeproj -scheme Yourly \
  -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO

# Relay: 136 tests, clean typecheck
cd transcription-service && npx vitest run && npx tsc --noEmit   # 137 tests
```

## Device stress pass — voice capture completeness

**Not runnable in CI or on a simulator, and it is the only pass that proves the thing it is about.**
A simulator has no microphone, so every capture there is silence of the right length; what this pass
measures is whether the *file* holds as much audio as the person actually spoke.

Added 2026-08-30, after two Home Quick Voice captures produced notes containing only the first few
seconds of a much longer recording. The client-side half of the evidence did not exist at the time and
now does; the server-side half existed but is not retained long enough to be read after the fact.

**Capture the server side first — it does not survive.** Fly keeps roughly the last twenty minutes of
log, so the run has to be recorded while it happens:

```bash
fly logs -a as-told-relay | tee -a voice-pass-relay.log | grep --line-buffered "transcription ok"
```

Each line carries `seconds` — the duration the relay measured **from the uploaded container**, never
from anything the client claimed. That is the authority on what was actually sent.

**The client side, from a DEBUG build on the device** (`VoiceDiagnostics`, metadata only — no
transcript, no audio, no note text, no file name):

```bash
log stream --device --predicate 'subsystem == "com.astold.app" AND category == "voice"'
```

```text
voice_capture_finished origin=quickVoice ending=userFinished recorded=27.80 asset=27.64 bytes=241328 drift=0.16
voice_capture_finished origin=quickVoice ending=unexpected  recorded=31.20 asset=6.41  bytes=58112  drift=24.79
```

`drift` is the whole point: `recorded` is how long the microphone was open, `asset` is how much audio
the finalized container holds. They agree on a healthy capture. The second line is the defect this
pass exists to catch, and it now also names itself in `ending`.

**The runs.** At least **20 Home Quick Voice** and **20 in-note**, roughly 20–30 seconds each, speaking
continuously. Across them, exercise: plain recording · Pause → Resume · AirPods connecting mid-capture
· AirPods disconnecting mid-capture · Control Centre pulled down and dismissed · backgrounding and
returning · Siri · an incoming call.

**Pass condition**, per run:

- `abs(recorded - asset)` within ~0.5s, and the relay's `seconds` within ~1s of `asset`.
- `ending` is `userFinished` for every run nothing interrupted.
- No run ends in a note whose text stops earlier than the speech did.

A single `drift` above a second is a finding, not noise — report the run, its `ending`, and the point
at which the audio stops.

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
