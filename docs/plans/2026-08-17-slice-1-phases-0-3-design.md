# Design — Implementation Slice 1 (Phases 0–3)

> **Status:** approved 2026-08-17. Scope: build the runnable, browsable **typed-notes** loop for
> [AppName] before any voice/backend work. This document is the implementation design; product
> behavior is owned by the specs in `docs/` and the rules in `RULES.md`.

## Goal

A runnable iOS app in the "Quiet Editorial" style, Light/Dark, matching
`docs/design-reference/screens-overview.png`, that lets a user: launch → (first run) Welcome → Home →
create a note → type → autosave → leave → reopen → edit → see notes grouped by day. **No voice, no
backend, no search/calendar/delete yet** (later slices).

Covers build-plan **Phase 0 → 1 → 2 → 3** (`docs/07-build-plan.md`).

## Toolchain & environment (verified 2026-08-17)

- XcodeGen 2.45.4, Xcode 26.3, Swift 6.2.4, iOS 26.2 SDK, iOS 26.3 simulator runtime, Homebrew present.
- Project generated from a source-controlled `project.yml` via `xcodegen`; `.xcodeproj` is gitignored.
- Verification: `xcodebuild test` on the iOS 26 simulator for logic; build + boot simulator +
  screenshots for UI.

## Project identity

- Xcode project / module / scheme: **`Yourly`** (working name from the design reference).
- Bundle identifier: **`com.yourly.app`** (placeholder, trivially changed later).
- `CFBundleDisplayName`: working name for now; product name stays `[AppName]` in prose per
  `CLAUDE.md`.
- Deployment target **iOS 26.0**, Swift 6 language mode.

## Repository & project structure

```
Yourly/
├── project.yml              XcodeGen spec — source of truth for the project
├── .gitignore               ignores Yourly.xcodeproj, DerivedData, .DS_Store, etc.
├── README.md CLAUDE.md RULES.md docs/   (existing)
├── App/
│   ├── YourlyApp.swift          @main, WindowGroup, model container
│   ├── AppRootView.swift        routes Splash / Welcome / Home
│   └── AppEnvironment.swift      DI container (NoteStore, settings)
├── Features/
│   ├── Welcome/WelcomeView.swift
│   ├── Home/HomeView.swift, HomeModel.swift, NoteRow.swift, DateGroupHeader.swift
│   └── Editor/EditorView.swift, EditorModel.swift
├── Core/
│   ├── DesignSystem/  DSColor.swift, DSSpacing.swift, DSRadius.swift, DSMotion.swift,
│   │                  Typography.swift, components (AppMark, PrimaryButton, FloatingNewNoteButton)
│   └── Persistence/   NoteStore.swift (protocol), SwiftDataNoteStore.swift,
│                      NoteGrouping.swift (pure date-grouping logic)
├── Models/Note.swift
├── Resources/
│   ├── Assets.xcassets   Canvas, SurfaceElevated, TextPrimary/Secondary/Tertiary, Accent,
│   │                     AppIcon (feather placeholder)
│   └── Localizable.xcstrings
└── Tests/YourlyTests/   Swift Testing units
```

## Architecture (per `docs/05-architecture.md`)

- Feature-oriented native architecture: SwiftUI views + `@Observable` models where state is
  non-trivial + protocol-backed `NoteStore` + environment DI + Swift Concurrency.
- **Data model** `Note` (`@Model`): `id: UUID` unique, `title: String?`, `body: String`,
  `createdAt`, `updatedAt`, `deletedAt: Date?`. Title whitespace-only normalizes to `nil`; timeline
  sorts by `createdAt`; grouping derives from `createdAt` via `Calendar.startOfDay`.
- **NoteStore** protocol (subset needed this slice): `createDraft`, `save`, `delete` (soft, unused
  UI this slice), `recent(limit:before:)`. Backed by `SwiftDataNoteStore` over `ModelContext`.
- **Routing:** `@AppStorage("hasCompletedWelcome")` drives Splash → Welcome (first run only) → Home.
  No tab bar.
- **Autosave:** editor model marks dirty on title/body change → debounced save (~400 ms) → flush on
  navigation away and on scene `inactive/background`. Empty-draft cleanup on exit when normalized
  title and body are both empty.

## Design system (per `docs/03-design-system.md` + reference)

- Adaptive Asset-Catalog colors using the §5.2 light/dark hex values, exposed as semantic
  `Color.ds.canvas` / `.textPrimary` / `.accent` etc. Warm off-white / near-black canvas; dark-navy
  accent for Continue button, floating `+`, (later) selected calendar day.
- 4-pt spacing scale, radius scale, motion tokens. System San Francisco + Dynamic Type for all UI
  text. The serif "Yourly" wordmark + feather mark are brand assets (`AppMark`), **not** a UI font.
- SF Symbols only (`plus`, `calendar`, `mic`, `chevron.left`, `ellipsis`). No emoji, no cards on
  Home rows — typography + whitespace rhythm.

## Phase deliverables

- **Phase 0 — foundation.** `project.yml`; app launches; system Light/Dark; SwiftData container
  boots; design tokens + adaptive colors render in Preview; feather placeholder app icon/mark.
  _Done when_ app launches, theme follows system, tokens render, container initializes.
- **Phase 1 — first run + Home shell.** Splash (mark + wordmark); Welcome (mark, wordmark, tagline,
  explanation, Continue) shown once; empty Home (uppercase date, "Today", calendar placeholder, empty
  copy, floating `+`); `hasCompletedWelcome` persists. _Done when_ fresh install =
  Launch→Welcome→Continue→empty Home; relaunch = Launch→Home; no permission prompts.
- **Phase 2 — Note model + editor.** `Note` + `NoteStore`; `+` opens Editor (auto date, optional
  `Title`, autofocused body `Start writing…`, mic placeholder, no Save/toolbar); autosave; empty-draft
  cleanup; edit existing note without moving it to Today. _Done when_ typing is a complete usable
  loop; text survives relaunch.
- **Phase 3 — Home timeline.** Fetch recent notes; note row (title+preview, or body-only when no
  title, never `Untitled`); day-group headers (Today / Yesterday / localized date); continuous lazy
  loading; no visible pagination. _Done when_ Home is stable and premium with 0 / 1 / many-today /
  many-days / long+absent titles / long bodies / large Dynamic Type.

## Testing & verification

- **TDD for pure logic** (Swift Testing, run via `xcodebuild test` on the simulator): title
  normalization, empty-draft rule, `createdAt`-based day grouping incl. timezone/DST, Today/Yesterday
  labels, pagination cursor, `NoteStore` CRUD + relaunch persistence.
- **UI verification:** build + boot iOS 26 simulator, capture screenshots of Welcome, empty Home,
  Editor, and populated Home in Light **and** Dark; compare against `docs/design-reference`.

## Out of scope for this slice (later plans)

Voice recording/transcription, transcription backend, App Attest, search, calendar sheet, swipe
delete + Undo, settings + Face ID lock, privacy cover. Tracked by build-plan phases 4–13.

## Risks / notes

- SwiftData migrations: schema versioned deliberately before public release (not yet needed).
- Keep dependencies at **zero** third-party this slice.
- `[AppName]` remains the product name; `Yourly` is only the code/module working name.
