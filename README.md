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

- **Home's library is a monochrome grouped list (changed 2026-08-30).** The note library below Home's
  header was redesigned for scanning density; the **header is untouched** — Profile, Calendar, New
  Note, Quick Voice and `.searchable` keep their positions, order and behavior, and no overflow menu
  or bottom toolbar was introduced. Four locked decisions moved with it, deliberately and together:
  notes group by **relative period** (`Today` / `Previous 7 Days` / `Previous 30 Days` / `Older`)
  rather than by day; a period is **one rounded surface holding many rows**, which is still not a
  card per note; a row is a title over a flattened body excerpt; and the palette
  is **neutral** — the warm `#F8F7F3` canvas and cream dark ink are gone, because no brand colour
  belongs on a content surface. The prominent largeTitle `Today` anchor went with the change, since
  `Today` is now a heading and drawing it twice is a bug. **Monochrome scopes to content and
  surfaces, not to navigation** (settled 2026-08-31, after a day with the header drawn in
  `textPrimary`): the four header glyphs keep their own muted tints — Profile terracotta, Calendar
  sage, New Note slate blue, Quick Voice lavender — because colour that tells one control from
  another is doing a job their symbols alone do not. **What did not change: Home still shows no
  creation time on a row** — a `9:41 PM ·` preview prefix was proposed and dropped rather than unlock
  that. Design: `docs/plans/2026-08-30-home-library-redesign-design.md`; rules: `RULES.md` §1, §4.
- Product name is **As Told** (locked 2026-08-17). Full marketing name: **As Told — Private Notes**. App Store name and home-screen icon label: **As Told**. The internal Xcode target/module stays `Yourly`; the bundle id is `com.astold.app` (changed 2026-08-18, before any App Store Connect record existed — it is permanent now that one does). **Reviewed and approved 2026-08-26**: Apple ID `6804007726`, listing at `https://apps.apple.com/us/app/as-told/id6804007726`. The id lives in two places that feed everything else — `APP_STORE_ID` in `website/lib/site.ts` and `AppLinks.appStoreID` in `Features/Profile/PrivacyView.swift`.
- Primary descriptor: **A private place for anything you want to put into words.** Brand promise: **Your words, as told by you.** (Repositioned 2026-08-18 from the thoughts-only *"Private notes, in your own words."* framing. This **widens the invitation, not the product**: V1 shipped scope, the do-not-build fences, and all shipped-feature marketing claims are unchanged; structured writing and voice-structure commands are sequenced roadmap, not V1. Tagline is unchanged. Full brand / ASO / SEO / website direction: `docs/08-positioning-marketing.md`.)
- **Links and code blocks live inside `body` (added 2026-08-23 — V2 Phases 1–2, both free).** `body`
  stays one plain `String`. A link is a bare `http(s)` URL exactly as written, or `[text](url)` written
  only by paste when a clipboard states a hyperlink whose text differs from its href; `http`/`https` are
  the only schemes As Told will open. A code block is a complete ` ``` ` fence pair whose interior is
  **literal** — a `#` there is a comment, not a heading. Both are read back, never written over the
  writer's own characters, and both follow the table rule of two presentations: a real view while
  reading, canonical source while editing. This retires three V1 exclusions one at a time, as
  `docs/09-v2-roadmap.md` §8.1.3 requires — see the links and code-block exceptions in `RULES.md` §7 and
  the storage contract in §5.
- **Code cards carry syntax colour and a language label (added 2026-08-24).** The line above read
  "syntax highlighting is deliberately **not** in this pass", which was right for the pass that built
  the card and wrong to keep: a monochrome block does not meet that exception's own bar, *code pasted
  into As Told should still look like code*. Colour is applied **only inside the rendered card**, only
  for a language the fence **named** (a closed list — a language is never inferred from the code), and
  only as colour: five tokens, semantic Light/Dark, each measured at or above 4.5:1 on `CodeSurface`.
  `body` is untouched, Copy Code still copies the original code, and editing still shows the plain
  fenced source — there is no syntax-aware editor. A block that named no language shows no label
  rather than "Plain text". See `RULES.md` §7 and `docs/03-design-system.md`.
- **Paste infers code, and only code** (amended 2026-08-24, by the product owner). The locked rule was
  "never infer structure from prose"; it now reads *never infer document structure from plain prose,
  **except high-confidence programming/code detection on paste***. Plain text a detector is certain is
  code is fenced automatically and arrives as a labelled, coloured card; anything short of certain stays
  prose, with **Paste as Code** as the manual override. This is the only inference from prose anywhere in
  the app. Bounds and rationale: `RULES.md` §4, `Core/Editor/CodeDetection.swift`.
- **The editor header is Back · date · Share (changed 2026-08-26).** The note's date moved from inside
  the scrolling page into the navigation bar, centred, and a native Share button joined it on the right.
  Sharing opens the **system share sheet** — no destination picker of our own, no overflow menu, and no
  second timestamp anywhere on the screen. This supersedes two earlier decisions on purpose: the
  2026-08-20 "the date scrolls with the document" fix (which was about a header pinned *inside* the
  page; a navigation bar reserves its own height, so the clipping it prevented cannot return through
  it — the **title** still scrolls, for that original reason), and the "no prominent timestamp" line in
  `RULES.md` §4. The date is `updatedAt`, in the reader's locale.
- **Sharing one note is free, and is not Export (added 2026-08-26).** One note, two representations —
  HTML for destinations that negotiate for it and UTF-8 text for the rest — both produced by
  `StructuredTextExport`, the same exporter the pasteboard uses. It is Copy with a destination attached.
  The Pro **Export & Restore** feature (`docs/09-v2-roadmap.md` §2.2) is a different thing and is still
  unbuilt: selected notes, a versioned backup format, a restore path. `native Share Sheet` was already a
  §7 P1 candidate; `share extension` — As Told appearing inside *other* apps' sheets — stays excluded.
- iPhone only, **portrait only** (locked 2026-08-18). No iPad, Mac Catalyst, or visionOS.
- No account or sign-in.
- No onboarding carousel.
- One first-run welcome screen.
- Tagline: **Write it. Say it. Keep it.**
- Home is the **recent** notes surface — the current date over `Today` and `Previous 7 Days`, capped
  at 4 and 5, with a reversible `Show all N` / `Show less` per period, and one **`Browse older
  notes`** into the complete timeline **only when notes actually sit outside those periods**
  (changed 2026-08-31; `RULES.md` §1). Four surfaces, four questions: Home *what was I working on
  recently*, All Notes *show me everything*, Calendar *what did I write that day*, Search *where is
  that note*. All Notes is an extension of Home, not a second organization system: same grouping,
  same rows, and no search, sort, filter, layout, folders, or counts of its own.
- Home carries **no app title and no note count** — the name is on the icon the reader just tapped,
  and the size of the library is a statistic Home does not report (`RULES.md` §1, §4).
- Notes are grouped automatically by relative period — `Today` / `Previous 7 Days` / `Previous 30 Days` / `Older` (changed 2026-08-30; was by day).
- No user-facing pagination or "Load more". A period-level `Show all N` / `Show less` toggle is permitted and is not pagination; All Notes may load older notes invisibly while scrolling (`RULES.md` §1).
- Search is available from Home using native pull-down/search behavior.
- Calendar is a secondary navigation tool for jumping to a date. It has **one** vertical scroll, its
  own sage accent for interaction state (chevrons, selected day, today's ring, density dots), at most
  **three** dots per day as a sense of activity rather than a count, and the selected day shows 4
  notes with the same `Show all N` / `Show less` Home uses (2026-08-31; `RULES.md` §1, §4).
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
  text. (`tables` was on the do-not-build list until this date; it now reads *table editing*.) **The
  delimiter row is never drawn** (2026-08-23): `| --- | --- |` records which row is the header and
  nobody typed it to be read, so it is absent from the card *and* from the source the writer edits. It
  is not removed — `body` keeps every character — so the caret is kept off that invisible line, and
  Backspace at the start of the first row joins that row to the header.
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
| `docs/10-voice-v2.md` | Voice V2 — **direction locked 2026-08-27, not built**: Home Quick Capture, pause/resume, recording durability, table-cell voice, the App Intent, and the seven-phase build order. Marks what already shipped in V1, and refuses self-corrections and the voice dictionary outright (`RULES.md` §2) |
| `docs/design-reference/screens-overview.png` | Canonical 10-screen visual reference for V1 |
| `docs/appstore/README.md` | The 6.9" screenshot set: what each frame shows, how it is composed, and the measurements it must pass |
| `docs/appstore/release-notes.md` | Per-version **What's New** text and what each submitted build contained |

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
