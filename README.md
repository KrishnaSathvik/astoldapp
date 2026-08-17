# Premium Notes App — Product & Engineering Docs

> **Working name:** `[AppName]`  
> **Tagline:** **Write it. Say it. Keep it.**  
> **Platform:** iPhone / iOS  
> **Product style:** Quiet Editorial  
> **Status:** V1 specification — ready to begin implementation  
> **Last updated:** 2026-08-17

## 1. Product in one sentence

A private, local-first iPhone app for capturing a thought exactly as it came to you — by typing or speaking.

The app is intentionally **not** a productivity workspace, AI writing assistant, traditional folder-based notes system, or journaling program. It should feel like a personal space that opens quickly, gets out of the way, and lets the user write or speak.

## 2. Locked V1 decisions

These decisions should be treated as product constraints unless intentionally changed later.

- No account or sign-in.
- No onboarding carousel.
- One first-run welcome screen.
- Tagline: **Write it. Say it. Keep it.**
- Home is the complete chronological notes timeline.
- Notes are grouped automatically by day.
- No user-facing pagination or "Load more".
- Search is available from Home using native pull-down/search behavior.
- Calendar is a secondary navigation tool for jumping to a date.
- Note title is optional.
- Empty notes are discarded automatically.
- Home does not show note creation times.
- Editor shows the note date, not a prominent time.
- Notes autosave.
- No visible formatting toolbar.
- Voice and typing are two input methods for the same note.
- Voice transcript becomes ordinary editable text.
- V1 voice target: English, Telugu, Hindi, Telugu+English, Hindi+English.
- Voice must not intentionally translate, summarize, rewrite, or grammar-correct.
- No audio is retained after successful transcription in V1.
- Face ID / device authentication lock is optional.
- App content is obscured in the app switcher when privacy lock is enabled.
- Appearance is user-selectable in Profile → Settings → Theme: Light, Dark, or Use device settings (default), plus an Increase Contrast option. (The original spec locked system-only; the picker was added intentionally.)
- SF Symbols for system icons; no emoji-as-interface.
- No folders, tags, streaks, prompts, AI summaries, chat-with-notes, reminders, collaboration, or export in V1.
- SwiftUI native-first implementation.
- Local note storage using SwiftData.
- Transcription API key never ships inside the iOS application.

## 3. Document map

Root:

| File | Purpose |
|---|---|
| `README.md` | This overview: product summary, locked decisions, where everything lives |
| `CLAUDE.md` | Agent operating guide — read first when working in this repo |
| `RULES.md` | The non-negotiable product/engineering rules the agent consults for any doubt |

Specifications (`docs/`):

| File | Purpose |
|---|---|
| `docs/01-product-requirements.md` | Product requirements, goals, scope, user flows, success criteria |
| `docs/02-features.md` | Complete V1 feature inventory and acceptance criteria |
| `docs/03-design-system.md` | Screen behavior, UI/UX rules, light/dark system, design tokens |
| `docs/04-voice-transcription.md` | Voice product contract, language behavior, errors, quality benchmark |
| `docs/05-architecture.md` | iOS architecture, modules, models, flows, security and backend boundary |
| `docs/06-tech-stack.md` | Exact recommended technologies and why |
| `docs/07-build-plan.md` | Implementation order, phases, and definition of done |
| `docs/design-reference/screens-overview.png` | Canonical 10-screen visual reference for V1 |

## 4. Build philosophy

The app should be built as a **small native product**, not as a large architecture exercise.

Prefer:

- Apple-native APIs
- small feature modules
- explicit product rules
- testable services
- minimal dependencies
- local-first behavior
- no unnecessary backend state

Avoid:

- Redux-style global state
- huge coordinator layers
- unnecessary repository abstractions
- a backend database for notes
- user accounts
- embedding third-party API keys in the app
- custom UI when the system control already behaves beautifully

## 5. Suggested source tree

```text
AppName/
├── App/
│   ├── AppNameApp.swift
│   ├── AppRootView.swift
│   └── AppEnvironment.swift
│
├── Features/
│   ├── Welcome/
│   ├── Home/
│   ├── Editor/
│   ├── Voice/
│   ├── Calendar/
│   ├── Search/
│   ├── Settings/
│   └── AppLock/
│
├── Core/
│   ├── DesignSystem/
│   ├── Persistence/
│   ├── Audio/
│   ├── Transcription/
│   ├── Security/
│   ├── Networking/
│   └── Utilities/
│
├── Models/
│   └── Note.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.xcstrings
```

Backend:

```text
transcription-service/
├── src/
│   ├── server.ts
│   ├── routes/transcribe.ts
│   ├── services/openaiTranscription.ts
│   ├── security/appAttest.ts
│   ├── security/rateLimit.ts
│   └── observability/logger.ts
├── test/
├── Dockerfile
└── package.json
```

## 6. First implementation milestone

Do **not** begin with voice.

First prove the core product loop:

1. First-run welcome
2. Home
3. Create note
4. Type text
5. Autosave
6. Return Home
7. Edit existing note
8. Swipe delete + Undo
9. Search
10. Calendar navigation
11. Light/Dark
12. Face ID lock
13. Voice recording
14. Transcription integration
15. Voice quality benchmark

This prevents the external transcription system from blocking the entire application.

## 7. Primary product rule

> **The note is always more important than the interface.**

If a design or engineering decision makes the interface more visible while making writing slower, noisier, or more complicated, it is probably the wrong decision.
