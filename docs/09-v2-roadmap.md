# As Told V2 — Roadmap

> The V2 product model, the Free / Pro split, and the order the work happens in.
>
> **Status: non-authoritative until V2 begins.** Proposed direction, recorded 2026-08-22. **Nothing here
> is built**, nothing here is locked, and nothing here may start before the V1 release gate
> (`RULES.md` §8) is green. V1 is with Apple for review as this is written, so the contracts that
> describe the **submitted** product are deliberately left untouched — see §8.1 for when and how they
> change.
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
| Links | ✅ new in V2 |
| Code blocks | ✅ new in V2 |
| Improved rich paste | ✅ new in V2 |
| Smart Reminders | — |
| iCloud Sync & Backup | — |
| File / library Export & Restore | — |
| Expanded Voice | — |

**Copy and paste stay free, obviously.** "Export" here means dedicated file/library export and
backup/restore tooling — not preventing someone from copying their own words out of their own notes. A
user who can never get their text out of a free app does not own their notes, and §3 of `RULES.md` says
they do.

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
│
▼
1. LINKS                    Free
│
▼
2. CODE BLOCKS              Free
│
▼
3. RICH PASTE 2.0           Free
│
▼
4. PRO FOUNDATION           StoreKit plumbing
│
▼
5. SMART REMINDERS          Pro
│
▼
6. iCLOUD SYNC & BACKUP     Pro
│
▼
7. EXPORT & RESTORE         Pro
│
▼
8. EXPANDED VOICE           Pro
│
▼
V2 HARDENING                sync / recovery / paywall / privacy / accessibility
```

### Phase 1 — Links (Free)

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

### Phase 2 — Code blocks (Free)

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

### Phase 3 — Rich Paste 2.0 (Free)

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

### Phase 4 — Pro Foundation

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

### Phase 5 — Smart Reminders (Pro)

The first real Pro feature, and it ships **before** cloud — which respects the product priority order
rather than the revenue order. It comes immediately after the StoreKit foundation only because it needs
something to ask whether the user is Pro.

All Milestone D preconditions apply and are real work: `NoteSchemaV2` and a real `MigrationStage`,
soft-delete/undo suspending and restoring notifications, empty-draft purge exemption for a note with a
live reminder, and an externally addressable navigation destination that waits behind the app lock.

### Phase 6 — iCloud Sync & Backup (Pro)

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

### Phase 7 — Export & Restore (Pro)

After cloud is stable, because reinstall/new-phone recovery is the mainstream path and file export is the
advanced escape hatch. Ship: **Share / Export Note**, **Export Library**, **Restore Library**.

Be exact about duplicates, IDs, creation dates, modification dates, checklists, tables, links, code blocks,
reminders, and forward compatibility with later schema versions.

### Phase 8 — Expanded Voice (Pro)

Last, because it is the piece with a recurring bill attached. Measure V1 → choose the Pro allowance →
build the entitlement-aware quota in the relay (never the client — `RULES.md` §2).

---

## 4. Final Free vs Pro

The version that would eventually go on the website and the paywall — **once each row actually ships**
(`RULES.md` §7, marketing lags implementation).

| | **Free** | **Pro** |
|---|---|---|
| Unlimited notes | ✅ | ✅ |
| Local private storage | ✅ | ✅ |
| Headings & lists | ✅ | ✅ |
| Checklists | ✅ | ✅ |
| Tables | ✅ | ✅ |
| Links | ✅ | ✅ |
| Code blocks | ✅ | ✅ |
| Rich paste | ✅ | ✅ |
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
- ❌ shared notes
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
   Phase 7 needs the amendment.
5. **"A sync engine before sync is a product requirement"** is a §7 architecture non-goal. Phase 6 makes
   sync a product requirement; record that, rather than quietly building against the non-goal.
6. **`notifications`** stays on the do-not-build list; `reminders` is already reclassified as a guarded
   post-1.0 direction. Phase 5 needs the notification entry amended alongside it.
7. **Links and code blocks** are new block-level capabilities in an editor whose storage contract is a
   single plain `String` `body` (§5) with no rich-text storage. Both need their canonical in-body
   representation decided and written into §5 **before** implementation, the way tables did.
8. **Sequencing.** Nothing in V2 starts before the §8 release gate is green. Reopening schema migration,
   entitlements, and sync during V1 release validation is how a finished V1 becomes another month of
   regressions.

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
4. **Links and code blocks need their storage contract decided first**, before Phase 1 implementation:
   how each lives inside the existing `Note.body: String`. Same philosophy that made tables work —
   structured rendering without turning `body` into arbitrary rich text.
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
- Obsidian pricing: https://obsidian.md/pricing
- Bear: https://bear.app/
- Drafts Pro: https://docs.getdrafts.com/draftspro
