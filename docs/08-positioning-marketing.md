# Positioning, Brand & Marketing Direction

> Long-term positioning and the brand / App Store (ASO) / SEO / website / screenshot direction for
> **As Told**. Adopted 2026-08-18 with the "anything you want to put into words" repositioning.
>
> **Owning rules:** `RULES.md` §1 (descriptor, tagline), §7 (adopted direction + marketing-lags rule).
> **Owning specs:** `README.md` §2 (locked decisions), `docs/01` §1 (positioning), `docs/02` (adopted
> direction milestones). Where this doc and `RULES.md` disagree, `RULES.md` wins.

---

## 0. The one rule for everything in this document

> **Marketing must lag implementation. It describes the production app, never the roadmap.**

Do not publish a claim about headings, lists, checklists, voice-structure commands, offline
transcription, or any other capability until it works reliably in the **shipping** build. This applies
to the App Store listing, the website, ASO keywords, Open Graph copy, screenshots, and social. See
`RULES.md` §7 ("Marketing must lag implementation").

---

## 1. Positioning

### Previous framing (too narrow)

> A private place for your thoughts.

### New framing

> **A private place for anything you want to put into words.**

A user might open As Told to write a passing thought, a note, an idea, a long reflection, an
article/blog draft, a trip plan, meeting notes, something to remember, a grocery list, a checklist, a
rough outline, a story, a letter, or something they'd rather speak than type. **The app does not care
what kind of document it is, and never asks the user to classify it first.**

### The boundary (never crossed)

Widening the use cases does **not** turn As Told into Notion, Craft, Apple Notes, Todoist, Word, or
Obsidian. No databases, tables, kanban, folders-everywhere, nested workspaces, collaboration, comments,
Markdown UI, font/color pickers, block-type zoos, due-date/priority/recurring-task systems, productivity
analytics, streaks, or any AI rewriting / summaries / chat / generation. It remains a **writing space**,
not a productivity operating system. See `RULES.md` §7.

### Core principle

> **The page does not decide what the writing is. The user does.** One universal document supports many
> kinds of writing. The interaction stays: open → the "+" → blank page → write or speak → leave. There is
> **no** "What would you like to create?" chooser.

---

## 2. Messaging hierarchy

| Layer | Copy |
|---|---|
| Brand | **As Told** |
| Tagline (unchanged, do not change) | **Write it. Say it. Keep it.** |
| Primary descriptor | **A private place for anything you want to put into words.** |
| Website H1 | **Anything you want to put into words.** |
| Supporting statement | **Thoughts, notes, drafts, lists, plans — or whatever's on your mind. Write it or say it.** |
| Voice promise | **Your words, however they come.** |
| Product philosophy | **One page. Two ways to write.** |
| Privacy line | **Your writing stays yours.** |
| Simplicity line | **Less, deliberately.** |

### Brand name & tagline

Keep **As Told** — the broader product makes the name stronger (*your words, as told by you*). Do not
rename because the use case broadened. Keep the tagline **Write it. Say it. Keep it.** exactly — it
already fits articles, notes, checklists, plans, ideas, reflections, and anything else; it does not say
"Journal it." or "Capture your thoughts."

### Vocabulary

- **Use freely:** writing, words, notes, drafts, thoughts, lists, plans, speak, private, simple, quiet.
- **Use sparingly:** productivity, AI, second brain, smart, optimize, workflow.
- **Avoid entirely:** "AI-powered note-taking", "ultimate productivity", "capture everything
  effortlessly with intelligence", "10x your writing", "second brain".

---

## 3. Welcome screen

Keep it extremely minimal — not a feature list. See `docs/03-design-system.md` §4.2.

```text
[feather]

As Told

Write it. Say it. Keep it.

A private place for anything
you want to put into words.

Continue
```

Optional supporting line: *Type it or say it. As Told stays out of your way.*

---

## 4. App Store (ASO)

Apple currently indexes the **app name**, **subtitle**, **keyword field**, and **company name** for
search, allows the name and subtitle up to 30 characters each, and up to 100 bytes of keywords. Do not
keyword-stuff the name, do not duplicate searchable terms across fields, and do not use competitor
brands or irrelevant/misleading terms (Apple explicitly warns against this).

### App name

**As Told** (clean; no keyword stuffing).

### Subtitle — LOCKED 2026-08-18

**Notes, drafts, lists & voice** — 28 chars, verified against Apple's 30-char limit.

The gate is satisfied: structured writing (headings, subheadings, bullet, numbered, checklist) and the
nine voice structure commands ship in the editor milestone, so this is a description of the production
app, not the roadmap.

It was chosen over the verb-led **"Write, speak, draft and plan"** (also 28 chars) because a noun-led
subtitle states what As Told handles and carries stronger search language. Keep the verb-led line — it
is warmer and closer to the tagline's cadence — for **marketing copy and screenshot headlines**, where
it reads better than it searches.

Voice is the differentiator, not the whole category. The store story is:

> A private writing space for notes, thoughts, drafts, lists, plans, and whatever else you want to put
> into words.

Do **not** describe As Told as only a voice-notes app any more.

### Keywords

Don't repeat terms already in name/subtitle (notes, drafts, lists, voice). Suggested hidden set (~97
ASCII bytes — verified 97/100):

```text
journal,memo,writing,dictation,speech,text,thoughts,ideas,checklist,todo,private,diary,transcribe
```

Exclude competitor brands, misleading capabilities, and irrelevant high-volume terms.

### Promotional text (~150 chars, no unshipped claims)

> A quiet place to write, speak, plan, draft, and remember. Capture anything in your own words, organize
> it naturally, and keep it private with Face ID.

### Description direction

Opening:

> **Write it. Say it. Keep it.**
>
> As Told is a quiet, private writing space for anything you want to put into words.
>
> Capture a passing thought. Write a note. Work through an idea. Draft something longer. Make a plan.
> Build a list. Or tap the microphone and simply say what's on your mind. Typing and speaking belong on
> the same page, so you never have to decide what kind of note you're creating first.

Sections: **Write naturally** · **Say it instead** · **Make it whatever you need** · **Find it again**
(timeline / search / calendar) · **Speak the way you speak** (English, Telugu, Hindi, natural mix) ·
**Private by design** (no account, local library, optional Face ID).

Closing:

> Whatever you want to put into words — write it, say it, keep it.

**Remove any claim about headings / checklists / lists / voice commands until those capabilities are in
the shipping version.**

### Screenshots

The old sequence was built around *thoughts + voice*. The app is broader now, so the story changes —
shot 4 (shaping) is the important new one and carries the milestone:

1. *Anything you want to put into words.* — Home.
2. *Just start writing.* — clean editor.
3. *Or just say it.* — voice recording state.
4. *Shape it as you go.* — heading + paragraph + bullet + checklist in one real note. **The key new shot.**
5. *Keep your own words.* — multilingual voice (Telugu+English or Hindi+English).
6. *Notes. Drafts. Lists. Plans.* — several different documents side by side.
7. *Everything finds its day.* — timeline.
8. *Find it again.* — search / calendar.
9. *Private by design.* — Face ID / local storage.

Shot 4 must stay tasteful: one natural document that happens to use structure. The moment it reads as a
productivity dashboard, the implementation and the marketing have both gone too far (RULES.md §7).

---

## 5. Website

### Title & meta

- **Browser / SEO title:** `As Told — Private Notes, Voice & Writing for iPhone`
- **Meta description:** *Write or speak notes, thoughts, drafts, lists, and plans with As Told — a
  private iPhone writing app with multilingual voice transcription and Face ID.*

Write titles/descriptions for humans, not as keyword dumps (Google may rewrite either from page content).

### Hero

```text
[Feather] As Told

Anything you want
to put into words.

Thoughts, notes, drafts, lists, plans,
or whatever's on your mind.
Write it or say it.

[ Download on the App Store ]
```

- Eyebrow: **Private writing for iPhone** · One primary CTA (App Store); one secondary ("See how it
  works"). Do not add six CTAs.

### Sections

- **One page. Whatever it becomes.** — a thought needs no folder, a draft no workspace, a checklist no
  project-management system; show thought → draft → list → checklist in the *same* editor.
- **Just start writing.** — no setup, no document type, no formatting wall; spacious Editor.
- **Or just say it.** — mic → waveform → transcribing → document.
- **Speak the structure, too.** — *only after structured voice ships.* Checklist-by-voice example.
- **Your words, however they come.** — no rewriting, no summarizing, no polishing your personality away;
  keep copy matched to the actual transcription contract (`RULES.md` §2).
- **Speak the way you speak.** — English, Telugu, Hindi, and the natural mix (a real code-switch example).
- **Nothing to organize first.** — Timeline / Search / Calendar. Do not market folders.
- **Your writing stays yours.** — only claims the production behavior supports: no account required,
  local note library, optional Face ID, and an **accurate** voice-processing statement. **Never say
  "Nothing ever leaves your phone"** — transcription involves server processing (`RULES.md` §3).
- **Less, deliberately.** — no account, no folders, no productivity dashboard, no streaks, no AI
  rewriting, no workspace to configure. *Just somewhere good to write.*

### Final CTA

```text
[feather]  As Told
Whatever you want to put into words.
Write it. Say it. Keep it.
[ Download on the App Store ]
```

### Open Graph

Served at `https://astold.app/og.png`, 1200×630, referenced from every page (`og:image` +
`twitter:image`, `summary_large_image`). **Never ship `logo.png` as the social preview.**

- Copy: **As Told** / *Anything you want to put into words.* / **WRITE IT. SAY IT. KEEP IT.**
- Visual: warm ivory / porcelain canvas, deep charcoal type, refined serif for the brand and headline,
  clean sans for supporting text. One abstract feather mark whose negative-space cuts hint at an audio
  waveform. One premium dark-titanium iPhone, slightly angled, soft realistic shadow, generous negative
  space — not a feature collage.
- **The device must show the current structured-writing UI**, not the pre-milestone plain-text Home:
  a real note carrying a heading, body text, and a short checklist. Structure has shipped, so showing it
  is now accurate rather than a roadmap claim.
- No App Store badge, no fake ratings, no emoji, no dashboard UI, no bottom tab bar, no per-note
  timestamps on Home, no note cards, no heavy shadows.

**Shipped 2026-08-18** as `website/og.png` (1200×630, ~691 KB). Generated with `gpt-image-2` at
1792×1024, **with `Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` supplied as a reference
image** so the card carries the real app feather — its silhouette, lean, curving quill, chalky
dry-brush texture and pale rachis line — not a model-invented mark. The faint background silhouette is
the same feather. Fitted to 1.905:1 by height with edge-replicated side padding rather than cropped, so
no lettering or device edge is lost. The device shot shows the structured-writing UI: a note preview, a real
three-row checklist (two open, one ticked), and a draft, which is accurate now that structure ships.

> An earlier prompt revision carried the retired headline *"Your thoughts, in your own words."* and a
> plain-text Home mockup. Both were superseded before the asset was rendered; the shipped image uses
> *"Anything you want to put into words."*

### Social bio

> A private place for anything you want to put into words. Write it. Say it. Keep it.

Short: *Your private writing space for iPhone.*

---

## 6. SEO

Don't chase only the broad term "notes app". Build genuinely useful, product-specific content around
real strengths. Follow Google's guidance: useful content and crawlable structure over tricks or keyword
stuffing; accurate structured data only where the type genuinely applies.

### Topics

- **Core:** private notes app for iPhone · simple / minimalist notes app · distraction-free writing app ·
  voice notes for iPhone · speech-to-text notes · dictation notes app · private writing app · notes app
  without account.
- **Use-case (only once features ship):** writing drafts on iPhone · notes and checklist app · simple
  todo notes · writing and voice app · voice-to-checklist · speak a list into notes.
- **Multilingual:** Telugu / Hindi voice-to-text iPhone · Telugu/Hindi English voice notes · multilingual
  voice notes.

### Landing pages (start small)

**Rebuilt 2026-08-20 (site v9, Next.js App Router):** `/` · `/voice` · `/languages` · `/privacy` ·
`/support` · `/terms`, each with a unique title, description, canonical, and one H1, all listed in
the generated `sitemap.xml`.

`/voice` covers voice → editable note, spoken structure commands, punctuation without rewriting,
English/Telugu/Hindi and mixed speech, and what happens to the recording. `/languages` covers
code-switching and per-language fidelity. Both describe real, shipped behavior — they correspond to
genuine product capability, not SEO filler.

`/private-notes` was retired as a page: its subject was privacy, and that content now lives in the
homepage privacy section and on `/privacy`. Renamed and retired routes are 308-redirected in
`website/next.config.ts` — `/voice-notes` → `/voice`, `/multilingual` → `/languages`,
`/private-notes` → `/privacy`, plus the `.html` spelling of each, so no inbound link or indexed URL
is dropped.

Later, and only after the matching feature ships: `/writing-app` · `/telugu-voice-to-text` ·
`/hindi-voice-to-text` · `/speech-to-text-notes` · `/checklists`. Do not generate dozens of shallow
keyword pages.

### Technical checklist

Production origin is **`https://astold.app`** (matches the locked `com.astold.app` bundle id). Every
absolute URL — canonical, `og:url`, `og:image`, sitemap — is written against it.

Done (2026-08-18, re-verified on the v9 rebuild 2026-08-20):

- [x] Unique `<title>` and meta description per page
- [x] Exactly one H1 per page
- [x] `<link rel="canonical">` on every page
- [x] `robots.txt` (points at the sitemap)
- [x] `sitemap.xml` (all six pages; generated from `app/sitemap.ts`, kept in sync with the canonical set)
- [x] Crawlable internal links — `/voice` and `/languages` from the header and from the matching home
      sections; `/privacy`, `/support`, `/terms` from the footer. Product links live in the header only,
      utility links in the footer only — neither set is duplicated.
- [x] Permanent redirects from every v8 URL (both the clean and `.html` spellings)
- [x] Open Graph + Twitter `summary_large_image` on every page, pointing at `/og.png`
- [x] Favicon / apple-touch-icon / web manifest wired and verified

Outstanding:

- [x] **Ship `website/og.png`** — rendered and in place; every page references it (see §5 Open Graph)
- [ ] Point the `astold.app` DNS at the Vercel project, then re-verify canonicals resolve
- [x] Audit alt text — every screenshot carries a descriptive alt; only the brand mark and the CTA
      feather are `alt=""`
- [ ] Capture a blank-editor shot and a dark-editor shot (see `website/README.md` § Known gaps)
- [x] **Support contact for App Store Connect** — `krishnasathvikm@gmail.com`. This satisfies the
      contact App Review requires, and it is deliberately **not** published on the site: it is a
      personal mailbox, and a plain-text address on a crawled page is scraped within days.
      `SUPPORT_EMAIL` in `website/lib/site.ts` therefore stays `null`, and `/support`, `/privacy`
      and `/terms` keep the self-service answer (the FAQ, plus the app's own Writing help).
      The public **Support URL** on the listing is `https://astold.app/support`.
- [ ] Move support to a mailbox on `astold.app` and set `SUPPORT_EMAIL` — then all three pages
      become a real `mailto:` from one constant, and the personal address comes out of the loop
- [ ] JSON-LD only where the type genuinely applies (`SoftwareApplication` is the plausible one)

---

## 7. North star

> **As Told — Write it. Say it. Keep it.**
> A private place for anything you want to put into words.

The long-term differentiation is not "another notes app with voice transcription." It is **a writing
space where your hands and your voice can create the same page** — and the boundary that is never crossed:
**As Told can help structure your words; it must never replace your words.**
