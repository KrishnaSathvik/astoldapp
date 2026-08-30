# As Told V2 — Roadmap

> The V2 product model, the Free / Pro split, and the order the work happens in.
>
> **Status: Phases 1–3 built (2026-08-23 → 2026-08-25); Phases 4–8 not started.** Proposed direction,
> recorded 2026-08-22; progress recorded 2026-08-26. The three **free** editor phases — Links, Code
> blocks, Rich Paste 2.0 — are implemented, and their contract amendments landed in `RULES.md` §4/§5/§7
> and `README.md` §2 on the dates each phase started, one exclusion at a time, exactly as §8.1.3 required.
> **Sharing one note** shipped free on 2026-08-26 under the same discipline, but it is *not* a V2 phase —
> it is §7's `native Share Sheet` P1 candidate, recorded here only so Phase 7 does not mistake it for
> Export (§2.2).
> **Nothing in Phases 4–8 is built** — no StoreKit, no entitlement, no paywall, no reminders, no CloudKit,
> no export, no Pro voice allowance — and none of it is locked. (No *export*: the library, the backup
> file, the restore path. Handing one open note to the system sheet is a different act and already free.)
>
> The original sequencing rule (§8.8: nothing starts before the V1 release gate is green) was read as
> binding on the **Pro** work, not on the free editor phases; Phases 1–3 went ahead while V1 was with
> Apple because they touch no entitlement, no schema migration, and no sync. That is a decision this
> document is recording, not one it made in advance. **Phases 4–8 keep the original fence:** they do not
> start before the gate is green.
>
> **This document does not amend `RULES.md`.** Several items below are on the V1 do-not-build list or
> contradict a locked V1 decision. §8 of this doc lists every one of them and what must change, in
> `RULES.md` and `README.md` §2, before that item is written. Where this doc and `RULES.md` disagree
> today, **`RULES.md` wins**.
>
> **Owning rules:** `RULES.md` §1 (locked constraints), §2 (voice is free in V1), §3 (privacy),
> §7 (do-not-build, adopted direction, P1 candidates, marketing-lags rule), §8 (release gate).
> **Owning specs:** `README.md` §2, `docs/02-features.md` (Milestones C/D), `docs/04-voice-transcription.md`
> §14 (fair-use ceiling), `docs/05-architecture.md`, `docs/08-positioning-marketing.md`.

---

## 0. The one sentence

> **Free = write beautifully on this iPhone.**
> **Pro = your writing follows you, comes back, reminds you, and gives you more voice.**

There is still **one As Told app**. No modes, no storage tiers, no multiple Pro levels, and no second
"As Told Pro" SKU on the App Store.

The split is deliberate: **writing quality stays free; ongoing continuity and services that carry real
recurring cost become Pro.** A paywall that fences off headings, checklists, or search would make the
free app feel crippled on purpose, which is the opposite of the primary product rule — the note is more
important than the interface, and it is certainly more important than the business model.

---

## 1. Free

Free stays a genuinely complete notes app. Everything V1 shipped stays free, permanently.

| Feature | Free |
|---|:--:|
| Unlimited local notes | ✅ |
| Headings / subheadings | ✅ |
| Bullets / numbered lists | ✅ |
| Checklists | ✅ |
| Tables (import & display) | ✅ |
| Search | ✅ |
| Calendar browsing | ✅ |
| Light / Dark / system theme | ✅ |
| Face ID lock | ✅ |
| Multilingual voice | ✅ |
| Current free voice allowance (60 min / UTC month, 5-min recordings) | ✅ |
| Links | ✅ built 2026-08-23 |
| Code blocks | ✅ built 2026-08-23 |
| Improved rich paste | ✅ built 2026-08-24 |
| Syntax colour + language label | ✅ built 2026-08-24 (was scoped out; see Phase 2) |
| High-confidence code detection on paste | ✅ built 2026-08-24 |
| Preformatted blocks (diagrams, trees, aligned text) | ✅ built 2026-08-25 |
| Share a note (system Share Sheet) | ✅ built 2026-08-26 |
| Smart Reminders | — |
| iCloud Sync & Backup | — |
| File / library Export & Restore | — |
| Expanded Voice | — |

**Copy and paste stay free, obviously.** "Export" here means dedicated file/library export and
backup/restore tooling — not preventing someone from copying their own words out of their own notes. A
user who can never get their text out of a free app does not own their notes, and §3 of `RULES.md` says
they do.

**Sharing the open note is on the free side of that line, and shipped there** (2026-08-26). It is Copy
with a destination attached, not the first instalment of Export: one note, the system sheet, nothing of
ours around it. `RULES.md` §7 admits it as a narrow exception that leaves `export` reading exactly as it
did — the library, the backup file, and the restore path are still Pro and still unbuilt (§2.2 below).

---

## 2. Pro

One subscription. No tiers. Four things in it.

### 2.1 ☁️ iCloud Sync & Backup

This is **one feature**, not three marketing bullets (Cloud Notes + Sync + Backup).

What the user understands:

> **Your notes are safe in iCloud and follow you.**

It covers:

- notes stored in the user's own private iCloud
- automatic background synchronization
- reinstall As Told → the notes return
- move to a new iPhone → the notes return
- edits reconcile between installations
- works offline and catches up later
- no manual "make a backup" step

Apple's private CloudKit database is readable only by that user and counts against **their** iCloud
storage, not ours — which is what keeps this consistent with §3: we still hold nothing.

#### The architecture rule: Pro is not "cloud-only"

```text
FREE
Local SwiftData
     ↓
This iPhone only


PRO
Local SwiftData
     ↕
Private iCloud / CloudKit
```

Pro MUST keep working with the network off. Cloud is the **continuity layer**, never a precondition for
opening a note. A note that needs a network request to be read is a different product than the one V1
shipped.

So the distinction is:

- **Free = local only**
- **Pro = local + private iCloud**

**No As Told account, ever.** Sign-in stays forbidden (`RULES.md` §1). The user's Apple Account is the
only identity involved, and we never see it.

Implementation choice to be made at build time: **SwiftData's managed CloudKit configuration** vs.
**`CKSyncEngine`**, which keeps the local model ours and gives tighter control over what is sent and
when — relevant precisely because sync is entitlement-gated here. Evaluate both against the shipped
`NoteStore` before committing; do not assume the managed path.

### 2.2 📤 Export & Restore

Separate from iCloud because it solves a different problem.

- **iCloud Sync & Backup** = automatic continuity.
- **Export & Restore** = manual ownership and portability.

**This no longer includes sharing a single note.** That shipped free on 2026-08-26 and is not a step
into this feature — handing one open note to the system sheet answers "let me send this to someone",
while everything below answers "let me hold my whole library in my own hands". Scoping the Pro feature
around the second is what keeps the first from ever needing a paywall.

Scope, in order:

- export one note
- export selected notes
- export the whole library
- Markdown / plain text first
- an As Told backup file
- import an As Told backup
- restore an exported library

Do **not** open with PDF / DOCX / ePub. Build one reliable native backup format plus Markdown/text, and
**version the backup format from day one** — a backup that cannot be read by a later build is not a backup.

### 2.3 ⏰ Smart Reminders

Already adopted as a guarded post-1.0 direction: `RULES.md` §7 ("Post-V1 — note reminders") and
`docs/02-features.md` Milestone D own the full rules and preconditions. **Every guard there still
binds** — this section only adds that the feature is Pro.

Someone writes:

```text
Call Ravi tomorrow at 7
```

As Told offers:

> **Remind me tomorrow at 7:00 PM?**

They confirm. That is the whole feature.

V2 scope:

- detect explicit date/time language, on device, deterministically
- a subtle, ephemeral suggestion
- **never** schedule automatically
- user confirms the date/time
- one local notification
- tapping it opens that note (never bypassing the app lock — `RULES.md` §3)
- edit a reminder / cancel a reminder
- show it unobtrusively on the note

Still forbidden: tasks tab, inbox, projects, priorities, kanban, dashboards, habit tracking, recurrence,
snooze, calendar sync, and any task semantics on checklist items. As Told **remembers something from your
writing**; it does not become Todoist.

### 2.4 🎙️ Expanded Voice

Free keeps the V1 experience unchanged: 60 minutes per UTC month, soft ceiling, 5-minute recordings
(`docs/04-voice-transcription.md` §14). Pro gets substantially more.

```text
FREE
60 min / UTC month
5-minute recording cap

PRO
Much larger monthly allowance
```

**The Pro allowance is deliberately not chosen yet.** Pick it from measured V1 economics, not from a
guess: average and median transcription minutes, the 90th/95th percentile, cost per active voice user,
and how many users ever come near the free ceiling. This is the only Pro feature with a direct per-minute
cost, so it is the one that decides the price.

> **Superseded in part, 2026-08-27.** Voice V2's direction is locked (`docs/10-voice-v2.md`,
> `RULES.md` §2), and it moves **pause/resume and interruption recovery to Free**. The paragraph below
> is what it argues against: pausing a recording is how a recorder works, not a premium capability, and
> paywalling it would make the free voice interaction deliberately worse. **Pro voice is capacity and
> nothing else** — a larger monthly allowance, still unchosen until real V1 economics exist. Read the
> list below as superseded, not as pending.

Later Pro voice work, once the allowance is settled: pause/resume, stronger interruption recovery, longer
individual recordings **if** the data justifies it, and continued Telugu/Hindi/English code-switch quality
work. The contract does not move:

> **Preserve the words. Format the speech.**

---

## 3. Build order

**Do not build Pro first.** The three free editor features come first, because they are what makes the
free app worth subscribing on top of.

```text
AS TOLD V1 — shipped
│   + SHARE A NOTE          Free    ✅ built 2026-08-26
│     (a §7 P1 candidate shipping, not a V2 phase — hence unnumbered)
▼
1. LINKS                    Free    ✅ built 2026-08-23
│
▼
2. CODE BLOCKS              Free    ✅ built 2026-08-23 · 08-24 · 08-25
│
▼
3. RICH PASTE 2.0           Free    ✅ built 2026-08-24
│
▼
4. PRO FOUNDATION           StoreKit plumbing        ◻ not started
│
▼
5. SMART REMINDERS          Pro                       ◻ not started
│
▼
6. iCLOUD SYNC & BACKUP     Pro                       ◻ not started
│
▼
7. EXPORT & RESTORE         Pro                       ◻ not started
│
▼
8. EXPANDED VOICE           Pro                       ◻ not started
│
▼
V2 HARDENING                sync / recovery / paywall / privacy / accessibility  ◻ not started
```

### Phase 1 — Links (Free) ✅ built 2026-08-23

**Raw links** — `https://astold.app` typed or spoken into a note renders tappable.

**Rich pasted hyperlinks** — pasting text that carries an `href` keeps both halves:

```text
display text: Open reservation
destination:  https://...
```

UX requirements:

- tappable while reading
- editable without fighting the writer
- visibly distinct without blue-link noise (Quiet Editorial — `docs/03-design-system.md`)
- VoiceOver announces it as a link
- safe URL opening
- the URL survives copy/paste out

**Do not introduce generic rich text to support links.** Inline formatting stays forbidden (`RULES.md` §7);
a link is a destination attached to a run of text, not the first step toward a font picker. The storage
question — how a destination lives inside a plain `String` `body` — must be answered before this is built,
the way tables answered it with canonical pipe rows.

**What shipped.** The storage question was answered first, as required: `body` stays one plain `String`,
and a link is either a bare `http(s)` URL exactly as written or `[text](absolute-http(s)-url)`, the second
spelling written **only** by paste and only when the clipboard stated a hyperlink whose text differs from
its href (`Core/Editor/LinkSpan.swift`; `RULES.md` §5 and the links exception in §7, both amended
2026-08-23). Parsing is strict on purpose — `apple.com` in prose stays prose, `[see](this)` keeps its
brackets as words — and `LinkSpan` only ever *reads*, so a URL someone typed stays the characters they
typed. The bracket-and-destination syntax is hidden at the glyph layer, the caret is kept out of it, and
`mailto:` / relative / `javascript:` destinations keep their words and lose only the link. `links` left
the do-not-build list on that date, alone.

Tests: `LinkSpanTests`, `LinkCaretHardeningTests`, `LinkCodeStylingTests`, `LinkCodeExportTests`,
`MarkupDocumentLinkTests`.

### Phase 2 — Code blocks (Free) ✅ built 2026-08-23, widened 08-24 and 08-25

A dedicated block renderer. Source:

````text
```python
def hello():
    print("hello")
```
````

`CodeBlockView` requirements:

- monospaced
- subtle background, appropriate corner radius
- preserves indentation, whitespace, and line breaks exactly
- long lines scroll horizontally rather than wrapping
- selectable, with **Copy Code**
- optional language label
- correct in Light and Dark
- accessible

**Not in V2:** running code, an IDE, autocomplete, a compiler, a terminal, or elaborate syntax tooling.
Syntax highlighting is a later candidate. The bar for V2 is one sentence:

> **Code pasted into As Told should still look like code.**

**What shipped — and where this section was wrong.** A code block is a complete ` ``` ` fence pair in
`body`, and its interior is **literal**: `BlockKind.parse` does not run there, so a `#` inside a fence is
a comment and a `- ` is a YAML item (`Core/Editor/CodeBlock.swift`, `Features/Editor/CodeBlockView.swift`).
Both fences are required, so a stray ` ``` ` can never swallow the rest of a note. Three things went
further than this section planned, each recorded in `RULES.md` §7 on its date:

- **Syntax colour and a language label landed anyway (2026-08-24).** "Later candidate" did not survive
  contact with the sentence above it: a monochrome block does not meet the *should still look like code*
  bar. Colour is applied only inside the rendered card, only for a language the fence **named** (a closed
  list — never inferred from the code), and only as colour — five tokens, semantic Light/Dark, each at or
  above 4.5:1 on `CodeSurface`. `body` is untouched and editing still shows plain fenced source; there is
  no syntax-aware editor. (`Core/Editor/CodeHighlighting.swift`.)
- **Editing happens in place, in the note's own text view (2026-08-24).** The fences are storage, like a
  table's pipes: their glyphs are hidden, the caret cannot settle on a fence line, and the block keeps its
  card while it is being typed into. There is no second editor and no sheet.
- **Preformatted blocks (2026-08-25).** A fence declaring `text` is the same structure on one wider axis —
  an ASCII diagram, a directory tree, a column of aligned figures — labelled **Plain text**, never
  coloured, with **Copy Text**. Same rule in both cases: *do not touch these characters, and do not let
  them wrap.*

Everything else in the requirement list above holds: monospaced, quiet ground, indentation and whitespace
exact, optional language label, Copy Code, correct in Light and Dark, VoiceOver told what the card is.
Nothing runs, and `body` stays canonical fenced source.

**The last gap in this phase closed 2026-08-25.** "Long lines scroll horizontally rather than wrapping"
was true of the drawing but not of the finger: the pan rule (`Core/Editor/CardPanRule.swift`) shipped
scoped to **preformatted** blocks, so a wide **code** card drew a scroll indicator that nothing could
move. `CodeBlockView.scrollsHorizontally` now asks only whether a *rendered* card is wider than its
viewport, so code and diagram cards scroll on identical terms. Everything the narrow version protected is
unchanged and still tested: a card that fits claims no gesture, a block being edited claims none, ties go
to the note, Copy wins when the touch starts on it, the card stays transparent to taps so a tap still puts
the caret in the code, and the offset is presentation only — it never reaches `body` and is not persisted.

Tests: `CodeBlockTests`, `CodeDetectionTests`, `CodeHighlightingTests`, `CodeInPlaceEditingTests`,
`PreformattedBlockTests`, `PreformattedBehaviorTests`, `PreformattedDetectionTests`,
`PreformattedAlignmentTests`, `PreformattedCardTests`, `PreformattedImportTests`, `RealWorldDiagramTests`,
`PasteAsCodeTests`, `PasteAsPreformattedTests`, `TableInsideCodeTests`, `CardHorizontalScrollTests`,
`CardScrollUITests`, `PasteAsPreformattedUITests`.

### Phase 3 — Rich Paste 2.0 (Free) ✅ built 2026-08-24

With links and code blocks in place, upgrade the importer. Target sources: ChatGPT, Claude, Safari and
web pages, Apple Notes, Google-Docs-style rich clipboard content, HTML, RTF, and explicitly declared
Markdown.

```text
Heading          → Heading
Subheading       → Subheading
Paragraph        → Paragraph
Bulleted list    → Bulleted list
Numbered list    → Numbered list
Task/checklist   → Checklist
Table            → Table renderer
Hyperlink        → Link
Code block       → CodeBlockView
```

The existing rule is the whole discipline here:

> **Preserve declared structure. Don't guess structure.**

Do not infer Markdown from arbitrary plain text. Do not see `{ }` and decide something is code. Do not
decide stray pipes are a table. Paste stays predictable, which is the only reason people trust it.

**What shipped.** The whole mapping above is implemented across `RichPasteHTML`, `RichPasteMarkdown`, and
`RichPasteDocument`: an `<a href>` with an absolute `http(s)` destination keeps both halves as a link, a
`<pre><code class="language-…">` arrives as a labelled coloured card, a `<pre>` with no `<code>` in it
arrives as a **Plain text** block (`<pre>` is HTML's own word for preformatted), and a `<pre>`'s interior
lines survive the chat-app habit of wrapping each line in its own `<div>`. Markdown fences import as code
blocks, which retires the V1 limitation where a fenced `# ` line landed in `body` as a heading — `body`
now has a way to say *this is code*.

**One deliberate crack in "don't guess structure" (amended 2026-08-24, by the product owner).** The rule
now reads *never infer document structure from plain prose, **except high-confidence programming/code
detection on paste***. Plain text the detector is certain is code is fenced automatically; a diagram whose
lines carry real Unicode box-drawing characters arrives preformatted (2026-08-25). Both are bounded hard:
plain-text flavor only, after every stated flavor declines; only a language `CodeHighlighting` can colour;
a decisive signature or three supporting ones, with a prose guard that overrules any score; and not one
character of the clipboard altered — detection adds fences and nothing else. Anything short of certain
stays prose, with **Paste as Code** / **Paste as Preformatted** as the manual overrides. The asymmetry is
the design: code left as prose costs one tap, prose turned into a card is the note being rewritten. This
is the only inference from prose anywhere in As Told, and `CodeDetectionTests` keeps a negative corpus
deliberately larger than its positive one.

Tests: `RichPasteImportTests`, `RichPasteLinkCodeTests`, `ClipboardEncodingTests`,
`BlockRenderingScopeTests`, plus the code/preformatted suites listed under Phase 2.

### Share a note (Free) ✅ built 2026-08-26 — not a V2 phase

Unnumbered on purpose: this is `RULES.md` §7's `native Share Sheet` **P1 candidate** shipping, not a V2
feature arriving early. It sits here because it is the fourth free capability built after V1 and because
Phase 7 must not mistake it for the beginning of Export.

**What shipped.** A Share button in the editor header — Back · date · Share, with no overflow menu,
because Share is one button for one verb. It opens the **system sheet and nothing of ours**: no
destination picker, no "Export as Markdown", no As Told share menu. iOS already knows which apps are on
that phone and who was messaged recently, and it knows it without As Told learning any of it, which is
the only version of that feature §3 permits.

The note travels as **one item with two representations**, never two attachments — an `NSItemProvider`
carrying UTF-8 plain text and HTML, with the destination choosing. Mail keeps the links, Messages takes
the characters, and a note never arrives twice in one message. Both flavours come from
`StructuredTextExport`, the same exporter the pasteboard uses; a second exporter's first divergence
would be a note that copies correctly and shares wrongly.

Four things it deliberately does not do. It **invents no URL** for the sheet's header — `LPLinkMetadata`
gets the note's name and the app icon, because a fabricated web address is a link to nothing and a
network request on behalf of a note that never leaves the device. It **writes no file**; the payload has
a `suggestedName`, which is a name, not a path. It **never shares the placeholder** — an untitled note
sends no title. And it **changes nothing about the note** beyond committing a table cell that was
mid-edit, which is the writer's own edit landing through the ordinary undoable path: Share reads the
text view's own text, so a cell changed a half-second before the tap is what actually goes out.

Share stays **visible and disabled** on an empty note rather than appearing as the first character is
typed — a control that materialises mid-sentence is the header moving while somebody writes.

Native **Copy** in that sheet is Apple's, not ours. Getting it required the item to be a real
`NSString`-backed provider (`NSItemProvider(object:)`) rather than an empty one handed two data
callbacks; `init(item:typeIdentifier:)` looks equivalent and wraps the string in a property-list blob,
so plain-text destinations receive bytes that are not the note. Two tests pin that distinction.

Still forbidden, unchanged: an As Told account, an upload, a hosted note, a share *link*, collaboration,
and any record of what was shared or where. Sharing is local, free, and unlogged.

Tests: `NoteSharePayloadTests`, `ShareLatestEditTests`.

### Phase 4 — Pro Foundation ◻ not started

Only now does subscription infrastructure appear. **StoreKit 2.** Internally there are exactly two states:

```text
Free
Pro
```

Build: the entitlement service (from StoreKit's current-entitlements API), the paywall, purchase, restore
purchase, manage subscription, expiration and grace-period handling, a StoreKit test configuration, the
feature gates, and the App Store subscription metadata.

#### The critical rule

**Losing Pro MUST NOT lose notes.** If a subscription lapses:

```text
Writing             ✅
Editing             ✅
Reading             ✅
Search              ✅
Local notes         ✅

New cloud sync      ⛔
Pro reminders       ⛔ / existing reminders handled safely, never silently dropped
Expanded voice      → back to the free allowance
Pro export          ⛔
```

The note library is **never** behind the paywall. A person's own words are not a hostage.

### Phase 5 — Smart Reminders (Pro) ◻ not started

The first real Pro feature, and it ships **before** cloud — which respects the product priority order
rather than the revenue order. It comes immediately after the StoreKit foundation only because it needs
something to ask whether the user is Pro.

All Milestone D preconditions apply and are real work: `NoteSchemaV2` and a real `MigrationStage`,
soft-delete/undo suspending and restoring notifications, empty-draft purge exemption for a note with a
live reminder, and an externally addressable navigation destination that waits behind the app lock.

### Phase 6 — iCloud Sync & Backup (Pro) ◻ not started

The major Pro value, and the highest-risk work in V2.

**First activation.** A user with 347 local notes subscribes. As Told says something like:

> **Keep your notes in iCloud**
> Your notes stay available if you reinstall As Told or move to another iPhone.

Then:

```text
existing local library
        ↓
safe initial migration
        ↓
private CloudKit
        ↓
local + cloud stay synchronized
```

No "uploading your account" flow, because there is no account.

**This deserves more testing than anything else in V2.** At minimum: 0 notes; 1 note; thousands of notes;
airplane mode; network loss mid-sync; edits during the initial migration; the same note edited from two
installations; deletes (including interaction with the ~4-second soft delete); uninstall and reinstall;
iCloud unavailable; iCloud disabled; the iCloud account changing; low iCloud storage; subscription expires;
subscription renews; resubscribe after months away; and the app killed during migration.

### Phase 7 — Export & Restore (Pro) ◻ not started

After cloud is stable, because reinstall/new-phone recovery is the mainstream path and file export is the
advanced escape hatch. Ship: **Export Note to a file**, **Export Library**, **Restore Library**.

**"Share Note" is struck from this phase — it shipped free on 2026-08-26.** What is left here is the
file: a note written to disk in a named format, which is a different act from handing the system sheet a
payload that never touches the filesystem. Do not re-solve the second while building the first, and do
not let this phase quietly annex it.

Be exact about duplicates, IDs, creation dates, modification dates, checklists, tables, links, code blocks,
reminders, and forward compatibility with later schema versions.

### Phase 8 — Expanded Voice (Pro) ◻ not started

Last, because it is the piece with a recurring bill attached. Measure V1 → choose the Pro allowance →
build the entitlement-aware quota in the relay (never the client — `RULES.md` §2).

---

## 4. Final Free vs Pro

The version that would eventually go on the website and the paywall — **once each row actually ships**
(`RULES.md` §7, marketing lags implementation). As of 2026-08-26 the free rows through Share a note are
built; every Pro row is still unbuilt, so **none of the Pro column may appear in marketing yet.**

| | **Free** | **Pro** |
|---|---|---|
| Unlimited notes | ✅ | ✅ |
| Local private storage | ✅ | ✅ |
| Headings & lists | ✅ | ✅ |
| Checklists | ✅ | ✅ |
| Tables | ✅ | ✅ |
| Links | ✅ | ✅ |
| Code blocks & preformatted text | ✅ | ✅ |
| Rich paste | ✅ | ✅ |
| Share a note | ✅ | ✅ |
| Search & Calendar | ✅ | ✅ |
| Face ID | ✅ | ✅ |
| Voice transcription | ✅ | ✅ Expanded |
| Smart Reminders | — | ✅ |
| iCloud Sync & Backup | — | ✅ |
| Reinstall / new-iPhone recovery | No app-managed cloud recovery | ✅ |
| Export & Restore | — | ✅ |
| Account required | No | **No separate As Told account** |

---

## 5. Pricing — not locked

Reference points in this category today:

```text
Drafts         ~$1.99/mo
Bear           ~$2.99/mo
Obsidian Sync  ~$5/mo  ($4/mo billed annually)
```

As Told Pro would carry iCloud Sync & Backup, Smart Reminders, Export & Restore, and Expanded Voice — and
Voice is a real per-minute cost that local-only competitors do not have.

**Evaluate roughly $2.99–$4.99/month once the expanded voice allowance and real usage are known.** Do not
pick a number before Phase 8's measurements exist.

---

## 6. Explicitly not in V2

- ❌ iPad
- ❌ Mac app
- ❌ Android
- ❌ collaboration
- ❌ shared notes — a hosted note, a share *link*, or anything As Told keeps a record of. Handing one
  note to the system sheet is not this and shipped in V1 (`RULES.md` §7).
- ❌ folders / workspaces
- ❌ task management
- ❌ AI rewriting
- ❌ AI summaries
- ❌ generic rich-text editor
- ❌ code execution
- ❌ a custom As Told account system
- ❌ an As Told-hosted note database
- ❌ multiple Pro tiers

**Milestone C — Keep at Top** (`docs/02-features.md`) is not scheduled into V2 either. It stays what it
already is: evaluated later, only if people actually keep active drafts around.

---

## 7. Market precedent

This is not an invented monetization model.

- **Obsidian** — unrestricted local notes free; Sync sold separately ($5/mo, $4/mo annual).
- **Bear** — local notes free; iCloud sync reserved for Pro ($2.99/mo, $29.99/yr).
- **Drafts** — broad free tier; advanced features in Drafts Pro ($1.99/mo, $19.99/yr).
- **Apple's App Review Guidelines** name **cloud support** as ongoing value appropriate for an
  auto-renewable subscription.

The differentiator is that As Told's **core writing experience stays very good without paying**.

---

## 8. What must change in `RULES.md` before any of this is built

Every item below is a real conflict with a currently locked rule. Each needs a deliberate amendment — in
`RULES.md`, in `README.md` §2, and in the owning spec, in the same change — written the way the tables and
reminders exceptions were written. **Do not treat this document as that amendment.**

1. **A paid tier at all.** `RULES.md` §2 (locked 2026-08-21): *"Voice is free in V1 and MUST NOT be gated
   behind a purchase. There is no subscription, no credit balance, and no Pro tier — so there is also
   nothing to upsell, and no upgrade call to action may appear anywhere in the voice flow."* The wording is
   V1-scoped, but introducing Pro requires saying so explicitly, and requires deciding **where a Pro
   prompt may and may not appear** — the "no upsell in the voice flow" fence exists because hitting a
   ceiling mid-thought is the worst possible moment to sell someone something. **Decided in §8.1:** Pro
   becomes valid, the fence stays.
2. **The usage-meter prohibition vs. a sold allowance.** §2 forbids any usage meter, progress bar, credit
   count, or Profile usage screen, and forbids the relay from sending the client a used/remaining/total
   figure. Selling "a much larger monthly allowance" as a subscription benefit puts pressure on that rule
   (and App Store review expects the benefit to be described). **Decided in §8.1:** the prohibition
   stays — Pro is sold as "Expanded Voice", not as a number. The limit is a cost boundary, not a feature.
3. **`iCloud sync` and `cloud note storage`** are on the §7 do-not-build list (V1) and simultaneously
   listed as §7 P1 candidates ("optional iCloud sync (no custom account)"). Phase 6 needs the do-not-build
   entry amended the way `tables` → `table editing` was.
4. **`export`** — same: on the do-not-build list, and a P1 candidate as "export all (text/Markdown)".
   Phase 7 still needs the amendment. **Half of this closed on 2026-08-26**, but only the half that was
   never really `export`: §7 now carries a narrow exception for sharing *one open note*, written so that
   the `export` entry itself reads exactly as it did. The library/backup/restore amendment this item
   asks for is untouched and still owed by Phase 7.
5. **"A sync engine before sync is a product requirement"** is a §7 architecture non-goal. Phase 6 makes
   sync a product requirement; record that, rather than quietly building against the non-goal.
6. **`notifications`** stays on the do-not-build list; `reminders` is already reclassified as a guarded
   post-1.0 direction. Phase 5 needs the notification entry amended alongside it.
7. **Links and code blocks** are new block-level capabilities in an editor whose storage contract is a
   single plain `String` `body` (§5) with no rich-text storage. Both need their canonical in-body
   representation decided and written into §5 **before** implementation, the way tables did.
   **✅ Done 2026-08-23**, in that order: §5 gained the in-body contract for both — a bare `http(s)` URL or
   `[text](url)`, and a complete ` ``` ` fence pair whose interior is literal — before either was
   implemented, with the preformatted variant added 2026-08-25 and the paste-side code-detection exception
   added to §4 on 2026-08-24. `links` and the code-block exclusion left the do-not-build list on their own
   dates, separately. Items 1–6 remain open and untouched.
8. **Sequencing.** Nothing in V2 starts before the §8 release gate is green. Reopening schema migration,
   entitlements, and sync during V1 release validation is how a finished V1 becomes another month of
   regressions. **Amended in practice 2026-08-23:** Phases 1–3 proceeded during review because they add no
   schema migration, no entitlement, and no sync — the three things this rule was written to protect. The
   fence stands unchanged for **Phases 4–8**, which are exactly the work it named.

### 8.1 When the amendment happens, and what it says (decided 2026-08-22)

**Not while V1 is in review.** V2 planning MUST NOT silently change the contracts that describe the
product currently in front of Apple. After V1 is approved and live, and **before any V2 production code
is written**, there is **one deliberate V2 contract amendment**. These are the decisions it makes:

1. **Pro becomes valid in V2.** The blanket "no subscription, no Pro tier" rule (§2) is retired.
   **Kept, and carried forward into V2:** no upgrade call to action while someone is **recording,
   transcribing, or meeting a voice limit**. A voice failure or a reached ceiling MUST NOT become an
   interruption-style sales screen. The moment a spoken thought is at stake is not a moment to sell.
2. **The no-usage-meter rule stays** — including with Expanded Voice. Pro is sold as "Expanded Voice",
   not as `17 / 60 minutes`. The server stays authoritative and still MUST NOT send the client a used,
   remaining, or total figure. Revisit only if real users demonstrably need visibility — evidence, not
   anticipation.
3. **Retire V1 exclusions one phase at a time**, as each phase starts: links, code blocks, Smart
   Reminders / notifications, Pro, Export & Restore, iCloud Sync & Backup. **Do not lift the whole §7
   protection in one edit.** The list's value is that it holds while everything around it moves.
   **Honoured so far:** `links` left on 2026-08-23 and the code-block exception was written the same day;
   the preformatted widening on 2026-08-25 and the paste code-detection amendment on 2026-08-24 were each
   written as their own amendment. **Still on the list, untouched:** notifications, cloud sync, cloud note
   storage, export, subscriptions/Pro, and the sync-engine architecture non-goal.
4. **Links and code blocks need their storage contract decided first**, before Phase 1 implementation:
   how each lives inside the existing `Note.body: String`. Same philosophy that made tables work —
   structured rendering without turning `body` into arbitrary rich text. **✅ Done** — see §8.7.
5. **The sync-engine architecture non-goal changes only for Phase 6.** "Do not build a sync engine
   before sync is a product requirement" stays useful and stays binding right up until sync is actually
   being built.
6. **Keep at Top stays unscheduled.** It does not enter V2 merely because an older milestone document
   mentions it.

---

## 9. References

- Apple — App Review Guidelines (subscriptions; cloud support as ongoing value):
  https://developer.apple.com/app-store/review/guidelines/
- Apple — `CKContainer.privateCloudDatabase`:
  https://developer.apple.com/documentation/CloudKit/CKContainer/privateCloudDatabase
- Apple — Mirroring a Core Data store with CloudKit:
  https://developer.apple.com/documentation/CoreData/mirroring-a-core-data-store-with-cloudkit
- Apple — `CKSyncEngine`: https://developer.apple.com/documentation/CloudKit/CKSyncEngine-5sie5
- Apple — Scheduling a notification locally from your app:
  https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app
- Apple — StoreKit `Transaction.currentEntitlements`:
  https://developer.apple.com/documentation/storekit/transaction/currententitlements
- Apple — Collaborating and sharing copies of your data (the `UIActivityItemsConfiguration` pattern):
  https://developer.apple.com/documentation/uikit/collaborating-and-sharing-copies-of-your-data
- Apple — `UIActivity.ActivityType.copyToPasteboard` (why the item must be object-backed):
  https://developer.apple.com/documentation/uikit/uiactivity/activitytype-swift.struct/copytopasteboard
- Apple — `NSItemProvider`: https://developer.apple.com/documentation/foundation/nsitemprovider
- Apple — `LPLinkMetadata`: https://developer.apple.com/documentation/linkpresentation/lplinkmetadata
- Obsidian pricing: https://obsidian.md/pricing
- Bear: https://bear.app/
- Drafts Pro: https://docs.getdrafts.com/draftspro
