# RULES — As Told

> The single source of truth for **what must and must not happen** in this product.
> When any doc, ticket, or instinct conflicts with a rule here, this file wins unless
> the rule is intentionally changed (and this file is updated in the same change).
>
> Every rule links back to the spec that owns the full reasoning. If you are unsure,
> read the linked spec — do not guess.

**Primary product rule**

> **The note is always more important than the interface.**
> If a decision makes the interface more visible while making writing slower, noisier,
> or more complicated, it is probably the wrong decision.

---

## 0. How to use this file

- Rules are grouped by area. Each rule is written as an absolute **MUST** / **MUST NOT** / **DO NOT**.
- "V1" means the first shippable version. Rules marked _(V1 only)_ are scope decisions that may
  be revisited later; all other rules are product/privacy/security contracts.
- Spec references: `docs/01-product-requirements.md` … `docs/07-build-plan.md`.

---

## 1. Locked product constraints (V1)

Source: `README.md` §2, `docs/01-product-requirements.md` §6.

These are treated as fixed product constraints unless intentionally changed.

- MUST NOT require an account or any sign-in (no Sign in with Apple).
- MUST NOT show an onboarding carousel. Exactly **one** first-run welcome screen.
- Tagline is **"Write it. Say it. Keep it."** and MUST NOT change.
- Primary descriptor is **"A private place for anything you want to put into words."** (Repositioned
  2026-08-18 from the thoughts-only framing — this widens the *invitation*, not the *product*. See
  `README.md` §2 and `docs/08-positioning-marketing.md`.) The product still refuses to become Notion /
  Todoist / Word / an AI writing assistant; the do-not-build fences in §7 hold.
- Home MUST be the complete chronological notes timeline (no separate "All Notes" screen).
- Notes MUST be grouped automatically by day.
- MUST NOT expose user-facing pagination or a "Load more" control.
- Search MUST be available from Home via native pull-down/`.searchable` behavior.
- Calendar is a **secondary** navigation tool for reaching a date — not a second database UI.
  Selecting a day lists that day's notes **on the calendar itself**, and opening one returns there
  (changed 2026-08-19, replacing the day-filtered Home mode). The fence that keeps it from becoming
  a second browsing surface: the day list is rows and nothing else — no search, no sort, no
  grouping, no pagination, no counts, the same `NoteRow` Home uses. Home remains the only complete
  timeline.
- Note title MUST be optional. MUST NOT ever render `Untitled`.
- Empty notes (no meaningful title or body) MUST be discarded automatically.
- Home MUST NOT show note creation times on normal rows.
- Editor shows the note **date**, not a prominent time.
- Notes MUST autosave. MUST NOT show a Save button.
- MUST NOT show a visible formatting toolbar. Light structure — headings / subheadings / bullet /
  numbered / checklist — **shipped in V1** (§7) and is created by typing its marker or speaking its
  command, never by a control. Any affordance around it MUST stay contextual or collapsible, never a
  persistent formatting ribbon; structure MUST NOT visually dominate writing, and the app MUST still
  read as a page. The editor's `?` is help, shown only while editing, and applies nothing.
- Voice and typing are two input methods for the **same** note — not two note types.
- A voice transcript MUST become ordinary, editable text.
- V1 voice target languages: English, Telugu, Hindi, Telugu+English, Hindi+English.
- Face ID / device authentication lock is **optional** and opt-in.
- App content MUST be obscured in the app switcher when privacy lock is enabled.
- Appearance is user-selectable in Profile → Settings → **Theme**: Light / Dark / Use device settings
  (default = system). Persisted across launches; applied via `preferredColorScheme` at the app root.
  (Added intentionally — the original V1 spec locked system-only. When the theme is "Use device
  settings", the app still follows iOS.)
- MUST use SF Symbols for system icons. No emoji-as-interface.
- SwiftUI native-first implementation; local storage via SwiftData.
- The transcription API key MUST NEVER ship inside the iOS application.

---

## 2. Voice & verbatim-capture contract

Source: `docs/04-voice-transcription.md` (whole file), `docs/01-product-requirements.md` §10, `docs/02-features.md` (Voice sections).

**The core contract:** _Spoken thought → faithful text representation of that spoken thought._

> ### Preserve the words. Format the speech.
>
> Punctuation and capitalization are how written language *represents* speech — supplying them is
> transcription, not editing. Changing **which words the speaker used** is editing, and is never
> allowed. (Changed 2026-08-18 from an over-literal "no changes whatsoever" reading; the forbidden
> list below is unchanged.)

**MUST be allowed** (readability formatting):

- capitalization
- sentence boundaries and full stops
- commas, question marks, and exclamation marks where clearly supported by the speech
- punctuation inferred naturally from delivery
- paragraph breaks where a meaningful pause or topic change is reliably detected
- minimal whitespace around an inserted transcript

The transcription path MUST NOT intentionally:

- translate speech
- summarize speech
- rewrite or paraphrase speech
- polish or "fix" grammar
- replace vocabulary with different words
- change tone or make sentences "more professional"
- remove slang because it sounds informal
- convert Telugu/Hindi to English by default
- collapse mixed-language speech into a single language
- invent/hallucinate content during silence
- replace the user's content with an AI-generated interpretation

Worked example (the boundary in one pair):

| | |
|---|---|
| **Spoken** | `Actually I don't know maybe we can go Saturday but if Ravi is coming then Sunday is probably better what do you think` |
| **Allowed** | `Actually, I don't know. Maybe we can go Saturday, but if Ravi is coming, then Sunday is probably better. What do you think?` |
| **Forbidden** | `Ravi and I should probably go on Sunday instead of Saturday.` |

Additional voice rules:

- MUST NOT run the transcript through a general LLM cleanup pass (e.g. "fix mistakes",
  "clean grammar", "make readable"). Punctuation MUST come from the transcription model itself,
  never from a second generative rewrite pass.
- Allowed deterministic cleanup is limited to **transport/UI artifacts only** — e.g. trimming an
  accidental trailing transport newline, or preventing double spaces at an insertion boundary.
- The **contract metric** is content WER (`contentWordErrorRate` — case- and punctuation-insensitive),
  not raw WER. Raw WER and punctuation error rate measure readability and inform the model/prompt
  choice; only content WER, script preservation, and unwanted translation gate a release.
- Writing-system goal: Telugu → Telugu script; Hindi → Devanagari; preserve natural English terms
  inside mixed speech where the model can do so reliably.
- Language hints are **benchmark-driven, not assumption-driven**. MUST NOT force a single language
  on every recording — code-switching is a core use case. Fall back to model language detection if
  explicit hints reduce quality for a test group.
- On any failure, MUST NOT invent replacement text. Offer explicit actions (Retry / Discard / Try Again).
- V1 requires network for transcription. When offline after recording: retain the protected temp
  audio for **explicit** retry only, tell the user a connection is required, and MUST NOT silently
  upload later without user intent.
- Recommended path (V1): record completed audio → send file → transcription model → insert final
  transcript. Do NOT build Realtime unless the product later needs live text.
- The transcription **model MUST be chosen from measured performance** on the consented corpus
  (`compareArms` in `Core/Voice/TranscriptionBenchmark.swift`), never because a model is newer or
  generically recommended. V1 ships `gpt-4o-transcribe` until a benchmark run says otherwise.
- A capture interrupted by a call or Siri MUST finish with the audio recorded so far rather than
  discard the user's words. Leaving the editor mid-recording MUST cancel the capture and delete the
  temporary audio.
- Abandoned temporary recordings (crash / force-quit) MUST be swept at launch.

### Cursor insertion contract

- Capture the intended insertion selection/location **before** recording starts.
- When there is **no active cursor** (an existing note open for reading, keyboard hidden), the
  transcript MUST be appended to the end of the note — never dropped, never given its own object.
- Insert at the saved cursor anchor (replacing selected text only if that is explicitly intended);
  preserve surrounding content.
- The `TranscriptionService` MUST NEVER mutate the note directly — the editor owns insertion.
- May insert minimal boundary whitespace/newlines to avoid joining words; MUST NOT otherwise
  rewrite transcript content.

### Structure the words (roadmap — NOT in shipped V1)

The long-term goal is that anything creatable by typing is also creatable by speaking, on the **same
document model** — never a separate voice-only document system. When structured voice ships, these
contracts apply. They are roadmap: MUST NOT be marketed until shipped (see §7).

- "Preserve the words. Format the speech." extends to **"Structure the words."** Voice may *structure*
  the user's words when they explicitly ask; it MUST NEVER *replace* them. Everything in the forbidden
  list above (translate / summarize / rewrite / paraphrase / grammar-fix / re-vocabulary) stays forbidden.
- The command vocabulary is **small, fixed, and deterministic**: `new paragraph`, `new line`, `heading`,
  `subheading`, `bullet list`, `numbered list`, `checklist`, `next item`, `end list`. MUST NOT grow into
  dozens of commands, and MUST NOT use a generative model to *infer* what formatting the user "probably" wanted.
- **Safety rule:** when it is uncertain whether a phrase is a command or literal content, **preserve the
  spoken words** and take no action. Recognize a command only when it appears as a clearly isolated phrase,
  at a sentence/utterance boundary, using exact supported wording, in a context where the action is valid.
- **Punctuation belongs to the command.** A recognized command absorbs the whole punctuation run the
  model transcribed after it (`new paragraph...`, `heading…`, `checklist!`). Stray leftover punctuation
  MUST NOT land in the note. This never widens *recognition*: a phrase that was not a command stays words.
- **Boundary:** *Touch chooses where. Voice chooses what.* No hands-free navigation, selection, cursor
  movement, or deletion commands in this stage (e.g. "go to paragraph three", "delete last two paragraphs").
- **Architecture:** faithful transcription first → a conservative command parser → document actions applied
  by the editor. The transcription service MUST NOT mutate the document. Typing and voice MUST converge on
  one shared document-action layer rather than two independent formatting systems.
- Commands may launch in **English** first if that is the cleanest implementation; Telugu/Hindi command
  equivalents are evaluated separately and MUST NOT compromise code-switch transcription quality.

---

## 3. Privacy & security rules

Source: `docs/01-product-requirements.md` §11, §13, `docs/04-voice-transcription.md` §5, §13–14, `docs/05-architecture.md` §16–19, §22, `docs/06-tech-stack.md` §10–11, §19.

### Data ownership

- The note database MUST live in the app container on device (local-first). No cloud note DB in V1.
- Before the **first** recording ever leaves the device, the app MUST show a one-time disclosure
  naming the third party that transcribes it and MUST NOT upload until the user accepts. Microphone
  permission is permission to *record*, never permission to *send* (App Review 5.1.2(i);
  `docs/04-voice-transcription.md` §6). Declining MUST delete the recording and send nothing.
- The transcription service receives **only** the audio the user explicitly chose to transcribe,
  plus static instructions, allowed language hints, and non-content metadata.
- MUST NOT send the full existing note to the transcription model as context.

### Backend MUST NOT persist

- raw audio
- transcript text
- note title
- note body
- search terms

### Logging

- Server logs may contain **metadata only**: request ID, route, status code, latency, model id,
  audio byte size, approximate duration, coarse error category.
- MUST NEVER log audio, transcript, title, body, or search queries.
- Client logs (OSLog/MetricKit) MUST NOT contain note or transcript payloads.
- Crash logs MUST contain no note text.

### API key & endpoint

- The standard OpenAI API key MUST stay server-side. MUST NEVER be placed in Info.plist, app source,
  client-readable remote config, the Keychain as a bundled secret, or an obfuscated binary. **Non-negotiable.**
- HTTPS only.
- The transcription endpoint MUST be protected against abuse: App Attest validation, per-attested-install
  rate limiting, IP anomaly limits (secondary), request size limit, duration limit, MIME validation,
  timeout, and a server-side model allowlist. An anonymous public endpoint is NOT sufficient.
- App Attest is anti-abuse protection, **not** user authentication. Development builds need a controlled
  bypass; a generic `X-Debug-Bypass` MUST NOT work in production.
- A production relay MUST NOT boot with attestation off. The only way past that is
  `APP_ATTEST_ALLOW_UNPROTECTED=true`, which exists for the pre-launch staging deploy and MUST NOT be
  set on any build real users can reach.

### App lock & app switcher

- App lock is opt-in; authenticate at enable time and on return to active.
- When lock is enabled and the app leaves active state, note content MUST be covered before the system
  snapshot — readable text MUST NOT remain in the app-switcher snapshot or behind the lock UI.
- App lock is an access gate, NOT a claim of end-to-end encryption. MUST NOT market beyond the threat model.

### Temporary audio

- Lives only in an app-controlled temporary/application-support location, with iOS file protection and
  randomized names. MUST NEVER go to Photos or shared Documents.
- MUST be deleted on Cancel, on successful transcription, and on Discard; abandoned files MUST be cleaned
  on launch beyond the allowed retry lifetime.

### Analytics

- Prefer Apple platform diagnostics (App Store Connect analytics, MetricKit, OSLog).
- MUST NOT install any third-party session-replay SDK capable of observing typed note content.
- Any future custom analytics MUST NEVER include note text, transcript text, audio, or search queries.

---

## 4. UI / UX rules

Source: `docs/03-design-system.md` (whole file, incl. §0 Visual reference),
`docs/01-product-requirements.md` §8–9, §12.

> **Canonical visual target:** `docs/design-reference/screens-overview.png`. Match it for look and
> feel; where pixels and prose disagree on behavior, the specs and this file win.

### Brand mark & wordmark

- The brand is a minimal **feather/quill mark** + a **serif wordmark** logotype, used **only** on
  Splash, Welcome, and Lock screens.
- This is a **logotype asset**, not a UI font. MUST NOT set a serif as a UI text font — all UI text
  stays system San Francisco + Dynamic Type (see §6 tech rules and §4 tokens below). This does not
  weaken the "no custom font in V1" rule.

### Core UX rules (non-negotiable)

1. The note is more important than the interface.
2. Never require Save.
3. Never require organization before capture.
4. Never ask a permission before the user invokes the feature.
5. Prefer inline interactions over extra screens.
6. Prefer native iOS controls when they already solve the interaction.
7. Voice and typing are the same note.
8. Deletion is reversible for a short period (Undo).
9. No user-facing pagination.
10. No interface copy that judges, encourages, gamifies, or diagnoses the user.
11. No time-of-day greeting.
12. Do not show creation time on normal Home rows.
13. Follow the system Light/Dark setting by default. The Theme picker (Light / Dark / Use device
    settings, defaulting to device settings) is an intentional, kept setting — see §1 and
    `docs/03-design-system.md` §15. Do NOT add further colour themes.

### Home

- Header shows: subtle current date, prominent `Today`, and a Calendar action.
- MUST NOT show greeting, weather, current time, quote, writing prompt, streak, or statistics.
- Row: if a title exists → title (one line where possible, ~17 pt semibold) + 2–3 line body preview
  (~15 pt regular, secondary, comfortable leading); if not → the first meaningful body line becomes
  the primary content and reads at body weight. Never generate `Untitled`.
- No card per note by default — use typography, whitespace, optional subtle separator. Prefer
  `VStack` rhythm over rounded rectangles.
- Must remain navigable and premium with 0, 1, many-today, many-days, long/absent titles, long
  bodies, and large Dynamic Type. Verified at 500–1,000+ notes.

### Editor

- Required elements: Back, overflow menu, date, optional title field, body text area, mic control.
- The overflow menu holds **exactly one** action in V1: `Delete Note`, routed through the same
  soft-delete + Undo path as a swipe on Home (no confirmation dialog — Undo is the safety net).
  It MUST NOT become a drawer for share / export / duplicate / formatting / word count / pin; those
  are on the do-not-build list (§7) and an overflow is how they get in.
- Forbidden default UI: Save button, formatting bar, checklist button, attachment row, AI button,
  word count, prominent timestamp, toolbar occupying writing width.
- Title placeholder `Title`; body placeholder `Start writing…`. No visible box/border on either.
- Editing an old note MUST NOT move it to Today — timeline sorts by creation date, not last edit.
- Undo MUST cover structural editing exactly as it covers typing: **one user action is one undo step**
  — ticking a checkbox, Return continuing a list, Backspace demoting a line, a voice transcript landing —
  restoring precisely the text, structure styling, and caret that were there before, with redo available.
  A document mutation MUST NOT be applied by assigning the text view's whole string: that bypasses undo
  registration and leaves the stack describing text that no longer exists.
- Structure markers (`# `, `- `, `- [ ] `, …) are an internal encoding and MUST NOT be visible anywhere:
  not in the editor, not in Home/search previews, not to VoiceOver, and not in anything copied out of the
  app. Copy/cut MUST give other apps the page as it reads (`• Eggs`, `☐ Call Ravi`); the raw source may
  travel only in a **private** pasteboard representation, so an As Told → As Told paste keeps its structure.

**Reading vs editing (one screen, no mode toggle):**

- A **new** note opens ready to capture: the body takes focus and the keyboard appears.
- An **existing** note opens for **reading**: nothing becomes first responder and the keyboard MUST
  NOT appear. Tapping the title or body starts editing at the tapped location.
- MUST NOT add an explicit `Read Mode` / `Edit Mode` toggle.
- The keyboard MUST be dismissable natively — interactive dismissal while scrolling, and navigating
  Back. MUST NOT add a large custom "Hide Keyboard" control.
- Because autosave is the only save, a trailing `Done` MUST NOT duplicate Back. It may exist only as
  the standard keyboard-dismissal affordance, shown only while a field holds the keyboard.

### Autosave

- Debounce active typing (~300–600 ms, reference 400 ms), flush on navigation away, flush on app
  background/inactive, flush after successful voice insertion. Never require user confirmation.

### Empty drafts

- On exit, if normalized title is empty AND body is empty/whitespace AND no transcription is pending →
  remove the draft. Do NOT clean user spacing inside a non-empty body.

### Navigation

- No tab bar in V1 — not enough top-level destinations. Model: Welcome (first launch) → Home →
  {Editor → Voice, Search, Calendar → Editor, Settings → App Lock}.
  (Calendar was specified as a sheet; it ships as a navigation push inside Home's stack, which
  gives it the system back button and one obvious way out. Implementation is the source of truth
  here — changed 2026-08-19. See `docs/03-design-system.md` §4.6.)
- A note opened from the calendar MUST return to the calendar, with the same day still selected.
  Back always undoes the step the user took; it MUST NOT reroute anyone to Home.

### Design direction — "Quiet Editorial"

Avoid: SaaS dashboard aesthetics, excessive cards, generic glassmorphism, bright gradients, AI sparkle
icons, emoji controls, heavy shadows, colorful category systems, oversized floating controls,
decorative animation that slows capture.

### Design tokens (use semantic tokens, never scattered literals)

- Colors via semantic tokens (`Color.ds.canvas`, `Color.ds.textPrimary`, …) or adaptive Asset Catalog /
  native system colors. MUST NOT scatter `Color(hex:)` or `gray500` across views.
- Reference palette (light / dark): `canvas` `#F8F7F3`/`#101112`, `surfaceElevated` `#FFFFFF`/`#1A1B1D`,
  `textPrimary` `#1C1C1E`/`#F3F2EE`, `textSecondary` `#68686D`/`#A6A6AB`, `textTertiary` `#99999F`/`#747479`,
  `accent` `#314D63`/`#8AA9BE`, `onAccent` `#FFFFFF`/`#101112` (text drawn *on* an accent fill — not a
  fixed white, because the dark accent is light), `destructive` = iOS system red. Warm canvas/accent
  are custom adaptive tokens.
- Typography: system San Francisco + Dynamic Type-backed semantic styles. **No custom font in V1.**
  Editor line height ~1.35–1.45×.
- Spacing: 4-pt foundation (4/8/12/16/20/24/32/40/48/64). Default horizontal margin 20 pt (Home),
  20–24 pt (Editor).
- Radius: 8/12/18/24/pill — only where controls/sheets need shape. Do NOT wrap every note in a large radius.
- Icons: SF Symbols only. No emoji, no Font Awesome, no mixed icon libraries.
- Materials / Liquid Glass: use for **controls and navigation** (New Note, mic, recording surface,
  sheet/nav controls) — NOT for content. The content plane stays calm and opaque. Never put the whole
  editor or every note on glass.
- Shadows: default none; if a floating control needs one, extremely subtle and system-like.
- Motion: prefer SwiftUI transitions/springs over hardcoded web-style timing. Respect Reduce Motion.
- Haptics: selective (mic start/stop, delete, error). Never on every normal tap.

### Accessibility (required from first implementation)

- All text scales with Dynamic Type; controls MUST NOT clip or overlap at accessibility sizes.
- Every icon action has a clear VoiceOver label (`New note`, `Start recording`, `Open calendar`, …).
- Review contrast in both themes. Primary touch targets ≥ ~44×44 pt.
- MUST NOT communicate state by color alone (e.g. a calendar dot needs an accessible label/trait).
- Testing matrix per major screen: Light, Dark, Light+large type, Dark+large type, Reduce Motion, VoiceOver.

---

## 5. Architecture rules

Source: `docs/05-architecture.md` (whole file), `docs/06-tech-stack.md`.

### Client style

- Feature-oriented native architecture. SwiftUI views + `@Observable` feature models where state is
  non-trivial + protocol-backed services where mocking matters + SwiftData behind a small `NoteStore`
  + environment-based DI + Swift Concurrency.
- MUST NOT build: one giant `AppViewModel`, massive singleton state, dozens of use-case classes for
  trivial reads/writes, or backend DTO concerns imported into UI.

### Data model

- `Note`: `id: UUID` (unique), `title: String?`, `body: String`, `createdAt`, `updatedAt`,
  `deletedAt: Date?` (non-nil only during short undo/cleanup state).
- `title` normalized: whitespace-only → nil. `body` stays raw user content.
- Structure lives **inside `body`** as canonical line markers (`# `, `## `, `- `, `1. `, `- [ ] `,
  `- [x] `). MUST NOT introduce a block database, a rich-text/attributed-string format, or a second field:
  `body` stays a single plain `String`.
- Timeline sorting & date grouping use `createdAt`, not `updatedAt`.
- No `voiceNote` type, no transcript provenance, no audio URL after successful transcription.

### Persistence & pagination

- SwiftData behind the `NoteStore` protocol (`createDraft`, `save`, `delete`, `undoDelete`, `recent`,
  `notes(on:)`, `noteDays(in:)`, `search`) so search/persistence stay swappable.
- Home is continuous UX but cursor/date-based batches under the hood (e.g. latest ~40, then
  `createdAt < oldestLoaded`). Stable key `createdAt + id`. MUST NOT use offset/page numbers.

### Date grouping

- Always use `Calendar` semantics (`startOfDay(for:)`, localized Today/Yesterday, explicit date intervals).
- MUST NOT do manual 24-hour math (`now - 86400`) — it causes DST bugs.

### Delete / undo

- Short-lived soft delete (`deletedAt = now`); normal fetches filter `deletedAt == nil`; undo sets it
  back to nil; cleanup after the undo window and/or on next launch for expired records. Do not rely
  solely on a transient UI `UndoManager` for persistence safety.

### Search

- V1 = local lexical search over normalized title + body. No embeddings / semantic search.
- If realistic-data performance is poor, migrate behind `NoteStore` to SQLite FTS5/GRDB without
  changing feature UI. Measure (100 / 1,000 / 10,000 notes) before optimizing.

### Backend

- Small Node.js 24 LTS + TypeScript + Fastify relay. Routes: `GET /health`,
  `POST /v1/app-attest/challenge`, `POST /v1/app-attest/register`, `POST /v1/transcriptions`.
- No user account, no note persistence. Flow: validate size/content-type → App Attest verify →
  rate limit → temporary handling → OpenAI transcription → validate response → return transcript →
  destroy temp audio.
- Return only `{ requestId, text, languages }`. Do NOT return model internals or raw provider errors.

### Error model

- Define domain errors (`TranscriptionError`: `microphonePermissionDenied`, `noSpeech`, `offline`,
  `requestTooLarge`, `rateLimited`, `serviceUnavailable`, `invalidResponse`, `cancelled`).
- UI maps domain errors to concise human copy. MUST NOT display raw backend/OpenAI errors to users.

### Migration

- SwiftData schema MUST be versioned deliberately before public release. Do not assume V1's model is
  permanent, but do NOT add speculative fields (pinnedAt, audio metadata, sync metadata) now.

### Configuration

- Do NOT hardcode API base URL, max recording duration, request timeout, model name, or rate limits —
  use environment/build configuration.
- However, fundamental product behavior MUST NOT be remotely mutable in unsafe ways (e.g. remote config
  MUST NOT be able to turn verbatim capture into AI rewriting).

---

## 6. Tech-stack rules

Source: `docs/06-tech-stack.md`.

- iOS: Swift 6+, SwiftUI, SwiftData, Swift Concurrency, `@Observable`, LocalAuthentication, AVFoundation,
  URLSession, DeviceCheck/App Attest, `@AppStorage`, OSLog, MetricKit, SF Symbols, String Catalogs
  (`.xcstrings`), Swift Testing (+ XCUITest where needed). Recommended min target **iOS 26+** _(V1)_.
- Backend: Node.js 24 LTS, TypeScript, Fastify, Zod/schema validation, official OpenAI Node SDK,
  model `gpt-4o-transcribe`, Redis-backed rate limit if needed, App Attest verification, metadata-only
  logs. `gpt-transcribe` is a benchmark candidate and must not replace production until the
  multilingual quality gate passes (§8).
- Audio: AVFoundation, prefer `AVAudioRecorder`, temporary `.m4a` mono AAC, level metering. Do NOT
  downsample so aggressively that recognition quality suffers.
- Networking: URLSession + Codable. No Alamofire. Timeout, cancellation, correlation/request ID, typed
  error mapping; never leak provider error messages to UI.
- MUST NOT lower the deployment target silently and then re-create modern controls by hand.
- MUST NOT force `.preferredColorScheme(.light/.dark)`.

### Dependency policy

Prefer **zero / very few** iOS dependencies. Before adding a package ask: (1) Does Apple provide this?
(2) Is it solving a proven V1 problem? (3) Does it add privacy/security surface? (4) Can the app
survive if it's abandoned? Likely V1 iOS third-party dependencies: **none** (unless search performance
later justifies GRDB). Backend dependencies are normal and isolated.

### Not for V1 (and why)

- No Realm/Firebase/Supabase — no account, no custom sync, no collaboration, no server note DB.
- No Algolia/Elasticsearch/vector search for a local personal-notes V1.
- No Realtime transcription first — final text after Done is the intended UX.

---

## 7. Do-not-build list

Source: `docs/01-product-requirements.md` §6, `docs/02-features.md` (Later section), `docs/05-architecture.md` §25.

### Excluded product features (V1)

accounts · Sign in with Apple · folders · tags · pinning · favorites · full rich text (font pickers,
text/background colors, arbitrary block types) · Markdown UI · images · attachments · scanning ·
handwriting · databases · tables · kanban · nested workspaces · collaboration · comments · share
extension · widgets · watchOS app · reminders · notifications · journaling prompts · mood tracking ·
streaks · productivity analytics · AI summaries · AI rewriting · AI chat · semantic search · cloud note
storage · iCloud sync · export · audio archive.

> _(The manual theme selector was previously excluded but has been added — see §1. "checklists" was
> previously listed here as permanently excluded; reclassified 2026-08-18 as a guarded milestone, and
> **shipping in V1 as of 2026-08-19** — see "Adopted direction" below. Still not a task-management
> system. "Markdown UI" above means a Markdown **toolbar or preview mode**, which remains excluded; the
> typed marker syntax that produces a heading or a list is the shipped editor, not a Markdown UI.)_

### Adopted direction — sequenced and guarded

Repositioning As Told to "anything you want to put into words" makes a **very small** amount of writing
structure legitimate, built incrementally with hard guardrails. Full detail: `docs/02-features.md`
(Adopted direction) and `docs/08-positioning-marketing.md`.

**Milestones A and B were pulled forward and now ship in V1** (2026-08-19). They were planned as post-V1
work and this section described them that way; the code landed first and the rules had not caught up.
What follows is a record of that change, not a claim they were always V1 scope.

#### Shipped in V1 — Milestone A, structured writing

Implemented and covered by tests. Behavior locked as described:

- Block kinds: **paragraph, heading, subheading, bullet, numbered, checklist**. Nothing else
  (optional **quote** remains a later candidate).
- Canonical markers are stored **inside `body: String`** — the note stays plain text, no rich-text
  storage (§5). Markers are **visually hidden at the glyph layer, never removed** from the source.
- **Return** continues a list and exits an empty item; **Backspace** at line start demotes the block to
  a paragraph; the **checkbox gutter** toggles a checklist item.
- **Structured copy/paste** carries the source markers; **undo/redo** stays native and exact.

#### Shipped in V1 — Milestone B, voice structure commands

- Vocabulary, exactly nine: **new paragraph · new line · heading · subheading · bullet list ·
  numbered list · checklist · next item · end list**.
- Recognition is a **deterministic client-side parser**, not a model. Structure is applied **only on an
  explicit command**; anything uncertain stays literal text. This is the §2 contract in the editor:
  ordinary speech that merely *sounds* structured MUST NOT become a list.

#### Discoverability rule (added 2026-08-19)

Structured writing MUST remain available **without a persistent formatting toolbar**. Discoverability MAY
use **transient placeholders, contextual editing help, and one-time voice education** — a hint that
disappears on first keystroke, a `?` reference shown only while editing, and a single tip after the first
successful transcription. Help surfaces are **reference only**: they explain syntax and MUST NOT apply
structure, because a sheet of formatting buttons is the forbidden ribbon one tap deeper.

- **The "Style" control** (converting an existing block — "make this a heading") is a post-release item,
  design-tested before implementation. Preferred form: a small contextual `Aa` / Style action available
  only while editing, routing through the existing `setBlockKind` primitive. It MUST NOT arrive as a
  persistent formatting ribbon. Not a release blocker — typing markers and voice commands already work.
  See `docs/02-features.md` Milestone B2.
- **A checklist is content, not a task manager.** It means "write several things and tick them off." It
  MUST NOT bring due dates, deadlines, overdue states, priorities, recurrence, calendar scheduling, task
  inboxes, or notifications. A Todoist/Notion clone stays on the do-not-build list.
- **Keep at Top** (surfacing an active draft/checklist above the chronological timeline) is evaluated
  *only after* structured writing exists — and is not a folders/favorites/workspace system.

### Marketing must lag implementation

- Marketing (App Store name/subtitle/keywords/description/screenshots, website, OG, social) MUST describe
  the **production app**, never the roadmap. MUST NOT claim headings / lists / checklists / voice-structure
  commands, or any other unshipped capability, until it works reliably in the shipping build.
- Concretely: the App Store subtitle stays the current narrower line until the broader editor ships; only
  then does it move to **"Notes, drafts, lists & voice."** Same for any website/ASO copy about structure.
- MUST NOT claim "offline transcription", "nothing ever leaves your phone", or any privacy/capability
  statement the production architecture does not actually guarantee (voice transcription involves server
  processing — see §3).

### Architecture non-goals (do not build)

server-side note database · event-sourced note history · microservices · Kafka · GraphQL · vector DB ·
auth platform · realtime collaboration stack · a sync engine before sync is a product requirement.

> The backend exists **only** because paid transcription credentials cannot safely live in the client —
> not because the product needs a traditional cloud backend.

### P1 candidates (only after stable V1, not now)

Optional iCloud sync (no custom account) · keep original audio (off by default) · native Share Sheet ·
export all (text/Markdown) · Lock Screen / Control Center quick capture · Apple Watch capture · manual
appearance override (only if users ask) · pin note (evaluate against chronological philosophy first).

---

## 8. Release gate — V1 is not shippable until all are true

Source: `docs/01-product-requirements.md` §15, `docs/07-build-plan.md` (Definition of Done).

- Typing flow, note persistence, and empty-draft cleanup are stable.
- Search is useful at realistic note counts (tested to ~10k).
- Calendar navigation works across months, years, timezones, and DST.
- Face ID / device authentication behavior is tested (enable/cancel/failure/background/foreground).
- App-switcher privacy cover is tested.
- Microphone permission denial/recovery is tested.
- Transcription error and offline flows are tested (airplane mode, slow net, 500, rate limit, timeout,
  empty result, user cancel, app backgrounds mid-request).
- Voice benchmarks pass agreed thresholds for: English, Telugu, Hindi, Telugu+English, Hindi+English —
  on the consented corpus, with the model chosen by `compareArms`, not by assumption.
- Recording survives interruption (call/Siri), route change (AirPods), and backgrounding; no temp
  audio survives a force-quit.
- No transcript/audio content appears in server logs; no embedded OpenAI secret; temp audio deletion verified.
- Relay runs with `APP_ATTEST_REQUIRED=true` in production. (It ships `false` only for the staged
  first-registration rollout in `transcription-service/DEPLOY.md`; shipping V1 with it false leaves
  a paid endpoint open.)
- The attested-key registry MUST be durable when `APP_ATTEST_REQUIRED=true`. Apple's replay defence
  is an ever-increasing assertion counter, which only rejects a replayed assertion if the stored
  counter survives restarts and deploys — a process-local registry silently disables it and
  re-registers every install. `APP_ATTEST_DB_PATH` MUST point at a mounted volume; the relay refuses
  to start if enforcement is on without it.
- The challenge store and rate limiter are still in-memory, so the relay MUST stay single-instance
  (`min_machines_running = 1`, `auto_stop_machines = "off"`). Scaling out requires a shared store
  first — otherwise rate limits multiply by instance count and challenges fail across machines.
- Light / Dark / Dynamic Type / VoiceOver reviewed on every major screen, over the full flow:
  Welcome → Home → New Note → Type → Read Existing Note → Edit Existing Note → Voice → Search →
  Calendar → Delete/Undo → Profile → Face ID.
- No user-facing surface says `Yourly`: UI copy, accessibility labels, display name, App Store
  listing, website, and support content all read **As Told**.
- The verification suite in `docs/07-build-plan.md` ("Verification suite") is green at its stated
  baseline — 305 unit, 33 UI, 84 relay, clean typecheck, Release build succeeds. The UI suite flakes
  as a whole-suite run, so a UI failure MUST be reproduced with `-only-testing:` on the single test
  before it is treated as a regression — and MUST NOT be waved off as flake without that check.

### Release-blocking voice behavior

Even with acceptable overall WER, release is blocked if the system frequently: translates Telugu/Hindi
to English · collapses mixed-language speech into one language · invents content during silence ·
"improves" meaning · loses large sections of speech.

---

## 9. Build order (do not reorder without reason)

Source: `docs/07-build-plan.md`.

Build in **vertical slices** — prove the typed-note product loop before any voice/backend work.

`Phase 0` foundation → `1` first-run + Home shell → `2` Note model + editor → `3` Home timeline →
`4` delete + undo → `5` search → `6` calendar → `7` settings + privacy lock → `8` audio capture UX
(with a **fake** transcription service) → `9` transcription backend → `10` real transcription
integration → `11` language quality program → `12` premium polish → `13` privacy / App Store readiness.

- MUST NOT start by building transcription/backend while Home and Editor do not exist.
- Phase 8 audio UX is perfected against a deterministic **fake** service before Phase 9 backend exists.
- First ticket: `APP-001 — Create native project foundation` (see `docs/07-build-plan.md`).
