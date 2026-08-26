# Premium Notes App — Product & Engineering Docs

> **Name:** **As Told** (internal Xcode target/module: `Yourly`)  
> **Tagline:** **Write it. Say it. Keep it.**  
> **Platform:** iPhone / iOS  
> **Product style:** Quiet Editorial  
> **Status:** V1 implemented — in polish / release-readiness  
> **Last updated:** 2026-08-18

## 1. Product in one sentence

A private, local-first iPhone app for putting anything you want into words — a thought, a note, a draft, a plan, a list — exactly as it came to you, by typing or speaking.

The app is intentionally **not** a productivity workspace, AI writing assistant, traditional folder-based notes system, or journaling program. It should feel like a personal space that opens quickly, gets out of the way, and lets the user write or speak.

## 2. Locked V1 decisions

These decisions should be treated as product constraints unless intentionally changed later.

- Product name is **As Told** (locked 2026-08-17). Full marketing name: **As Told — Private Notes**. App Store name and home-screen icon label: **As Told**. The internal Xcode target/module stays `Yourly`; the bundle id is `com.astold.app` (changed 2026-08-18, before any App Store Connect record existed — it is permanent now that one does). **Reviewed and approved 2026-08-26**: Apple ID `6804007726`, listing at `https://apps.apple.com/us/app/as-told/id6804007726`. The id lives in two places that feed everything else — `APP_STORE_ID` in `website/lib/site.ts` and `AppLinks.appStoreID` in `Features/Profile/PrivacyView.swift`.
- Primary descriptor: **A private place for anything you want to put into words.** Brand promise: **Your words, as told by you.** (Repositioned 2026-08-18 from the thoughts-only *"Private notes, in your own words."* framing. This **widens the invitation, not the product**: V1 shipped scope, the do-not-build fences, and all shipped-feature marketing claims are unchanged; structured writing and voice-structure commands are sequenced roadmap, not V1. Tagline is unchanged. Full brand / ASO / SEO / website direction: `docs/08-positioning-marketing.md`.)
- iPhone only, **portrait only** (locked 2026-08-18). No iPad, Mac Catalyst, or visionOS.
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
- Writing controls live in **one floating toolbar above the keyboard** — `Aa` · `•` · `1.` · `☑` and
  the microphone — not in the navigation bar and never in a bar across the top of the page
  (`WritingToolbar`, **changed 2026-08-20**). Structure — heading / subheading / bullet / numbered /
  checklist — stays reachable three equivalent ways: tapping it there, a typed marker, or a spoken
  command (a control was added 2026-08-19, when the rule had read "never by a control"; it moved out of
  the header 2026-08-20, when the rule had read "a keyboard-accessory row of style buttons IS the
  forbidden bar"). Both reversals had one cause: a capability people cannot find is a capability the
  app does not have. The toolbar is contextual — absent while reading, absent while the title has the
  caret, and replaced by the recording panel while recording — and it carries **no new capability**:
  the same six structures, through the same `DocumentAction` primitive. Inline rich text (bold,
  italic, colors, alignment) stays forbidden, on this bar as everywhere else. The menu's plain-text row is **Paragraph** (renamed from `Normal`
  2026-08-19): it is the writer's explicit way *out* of a list, alongside pressing Return on an empty
  item, and either way the caret moves to the paragraph inset immediately. Rows are title case, and
  the bullet row is **Bulleted List** (2026-08-20) — the *spoken* command is still "bullet list", and
  a menu label and a spoken phrase are deliberately allowed to differ (RULES.md §1).
- **Tables are import-and-display only** (added 2026-08-21). A pasted table is kept as canonical pipe
  rows in `body`, styled as a table in the note, and openable full-screen with real columns and
  VoiceOver. There is no way to create or graphically edit one: no toolbar button, no row/column
  controls, no spreadsheet behavior, and voice never makes a table. Editing a table means editing its
  text. (`tables` was on the do-not-build list until this date; it now reads *table editing*.)
- Voice and typing are two input methods for the same note.
- Voice transcript becomes ordinary editable text.
- **Voice is free, with a quiet fair-use ceiling** (locked 2026-08-21). No subscription and no Pro
  tier, so no upsell appears anywhere. One recording is capped at **5 minutes** (changed from 10) and
  auto-finishes into a transcript rather than being discarded. An attested install gets **60 minutes
  per UTC month** as a *soft* ceiling — a recording started under the limit finishes whole, and only
  the next is refused. Enforced by the relay, never the client; only successful transcripts count.
  **No usage meter ships** — the limit is a cost boundary, not a feature. See `RULES.md` §1 and
  `docs/04-voice-transcription.md` §14.
- V1 voice target: English, Telugu, Hindi, Telugu+English, Hindi+English.
- Voice structure is **nine actions**, each accepting a small closed set of spellings (aliases added
  2026-08-19 — `start bullet list`, `bulleted list`, `start numbered list`, `start checklist`,
  `new item`, `stop list`, `normal paragraph`). More spellings, never more actions; structure is still
  never inferred from ordinary speech.
- Voice: **preserve the words, format the speech** (refined 2026-08-18). Natural capitalization,
  punctuation, sentence boundaries, and paragraph breaks are allowed; translating, summarizing,
  rewriting, paraphrasing, or grammar-correcting the user's words is not.
- The transcription model is chosen from measured benchmark performance, not model recency. V1 ships
  `gpt-4o-transcribe`.
- A new note opens with the keyboard; an existing note opens for reading with the keyboard hidden
  (locked 2026-08-18). No Read/Edit mode toggle.
- No audio is retained after successful transcription in V1.
- Face ID / device authentication lock is optional.
- App content is obscured in the app switcher when privacy lock is enabled.
- Appearance is user-selectable in Profile → Settings → Theme: Light, Dark, or Use device settings (default). (The original spec locked system-only; the picker was added intentionally.)
- SF Symbols for system icons; no emoji-as-interface.
- No folders, tags, streaks, prompts, AI summaries, chat-with-notes, reminders, collaboration, or export in V1.
- **Reminders are a guarded post-1.0 exception** (decided 2026-08-20, unbuilt). Still excluded from V1
  as above. After 1.0, a note may offer a **one-time local reminder** when the writer explicitly asks
  for one in their own words, typed or spoken — note-level, confirmation-only, on-device, and never a
  task manager. Checklists gain no task semantics. See `RULES.md` §7 and `docs/02-features.md`
  (Milestone D).
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
| `docs/08-positioning-marketing.md` | Long-term positioning, brand/messaging hierarchy, App Store (ASO), SEO, website, screenshots, and the marketing-lags-implementation rule |
| `docs/09-v2-roadmap.md` | **Proposed** V2 direction: the Free / Pro split, the eight-phase build order, and the rule amendments each phase would require (nothing in it is built or locked) |
| `docs/design-reference/screens-overview.png` | Canonical 10-screen visual reference for V1 |

Marketing site (`website/`):

| File | Purpose |
|---|---|
| `website/README.md` | How the site is built and deployed, the three rules it holds to, and how to regenerate the screenshots and the social card |

The site is a Next.js App Router app on Vercel serving `www.astold.app` (the apex redirects to it) — six routes, every one
statically prerendered, no environment variables. Its screenshots are captures of the shipping
app rather than mockups, so **it lags the product on purpose**: nothing is published there until
it works in the build (`docs/08-positioning-marketing.md` §0).

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

Marketing site:

```text
website/
├── app/                one route per directory; every page prerenders to static HTML
│   ├── layout.tsx      header, footer, metadata defaults
│   ├── globals.css     design tokens, lifted from the app's own light palette
│   ├── page.tsx        homepage
│   ├── voice/  languages/  privacy/  support/  terms/
│   ├── sitemap.ts      generated /sitemap.xml
│   └── robots.ts       generated /robots.txt
├── components/         shared building blocks, each with its own CSS module
├── lib/site.ts         canonical URL, nav, App Store listing, support contact
├── public/assets/shots/  screenshots of the shipping app, straight from the simulator
├── scripts/            screenshot + width audits, and the og.png generator
└── next.config.ts      permanent redirects from every retired URL, security headers
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
