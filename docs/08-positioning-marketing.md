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

### Voice positioning — repositioned 2026-08-28

> **Previous framing (too narrow):** *English, Telugu & Hindi.*
>
> **New framing:** **Multilingual voice transcription, including mixed-language speech.**

English / Telugu / Hindi were always the **benchmark groups** — the five sets whose quality is measured
before a release (`docs/04-voice-transcription.md` §3) — and were never the product's boundary. The relay
deliberately omits the `language` parameter, because forcing one would collapse code-switching, so the
shipped pipeline does not restrict what a person may speak. Marketing that led with three languages
described the test plan and made As Told read as a niche three-language app.

Headline the capability; keep the groups as evidence:

- **Use:** *Speak the way you actually speak* · *Multilingual voice transcription* · *Switch languages
  naturally* · *Your words stay in the language you used* · *No forced translation* · *Mixed-language
  speech is welcome*.
- **Never use:** *all languages* · *every language* · a language **count** · *perfect transcription* ·
  *understands any accent*. See `RULES.md` §7 ("Language claims"), which is binding.
- **English, Telugu, Hindi and the code-switched pairs stay on the page** — as a quiet line saying what
  has been tested most closely, in the register of a footnote, never as a headline or a chip row that
  reads like a supported-languages list.

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

**Live since 2026-08-26** — approved and on the store:
`https://apps.apple.com/us/app/as-told/id6804007726` (Apple ID `6804007726`, bundle `com.astold.app`).

That id is written in exactly two places in this repo, both of which derive every other use of it:
`APP_STORE_ID` in `website/lib/site.ts` (the site's CTAs and the iOS Safari smart banner) and
`AppLinks.appStoreID` in `Features/Profile/PrivacyView.swift` (the app's own "Rate As Told" row,
which is a `?action=write-review` deep link, not a rate-limited system prompt). Everything below
this line described the listing before it existed; it is still the copy of record for it.

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

Sections, revised 2026-08-29 for V2: **Write naturally** · **Say it instead** (Quick Voice from Home;
pause and resume) · **Make it whatever you need** (headings, lists, checklists, links, tables, code) ·
**Find it again** (timeline / search / calendar) · **Speak the way you actually speak** ·
**Share when you need to** · **Private by design** (no account, local library, optional Face ID).

The multilingual section is the one with a trap in it. Write the capability, then the evidence, in
that order and no other:

> **Speak the way you actually speak.**
>
> As Told doesn't ask you to choose a language before you talk. Speak in one, or move between two in
> the same sentence — the transcript comes back in the languages you used, in the scripts you used,
> rather than translated into one. Voice transcription is tested most closely with English, Telugu,
> Hindi, and speech that moves between them.

Do **not** write "English, Telugu and Hindi" as a supported-languages line, and do not write "all
languages", a language count, or any accuracy guarantee (`RULES.md` §7, "Language claims").

Closing:

> Whatever you want to put into words — write it, say it, keep it.

**Remove any claim about a capability until it is in the shipping version.** Everything listed above
ships as of 2026-08-29; iCloud sync, export/restore, reminders, Pro, App Intents, Siri and the voice
dictionary do not, and none of them may appear.

### Screenshots

**Rebuilt 2026-08-29 for V2 — `docs/appstore/README.md` is the operational truth; this is the story.**
The nine-shot V1 sequence that stood here was built around *thoughts + voice* and is superseded. Ten
frames, which is Apple's maximum:

1. *Anything you want to put into words.* — Home, `+` and the microphone side by side.
2. *Write it. Or just say it.* — Quick Voice listening, dark.
3. *Speak the way you actually speak.* — a code-switched note.
4. *Pause. Think. Keep going.* — the in-note recorder, paused.
5. *Structure without the complexity.* — the writing toolbar over a structured note.
6. *Code that still looks like code.* — the SQL card, dark.
7. *Paste it. Keep the structure.* — a pasted table.
8. *Your words shouldn't disappear.* — a retained recording, Retry / Delete.
9. *Find it again.* — timeline, search and calendar.
10. *Private by default.* — app lock.

Frames 1–3 carry the most weight: they can appear directly in search results and most people never
swipe past them. Frame 1 leads with **Home**, reversing V1's editor-first choice, because Home is
where the two ways into a note now sit beside each other.

Two constraints on this set, both recorded in `docs/appstore/README.md`:

- **No Share frame yet.** It cannot be captured from a simulator, which has no Messages, Mail or
  AirDrop; a sheet offering Reminders and Save to Files misrepresents where a note can go. It needs a
  device capture, and it displaces a frame when it arrives.
- **Frame 8 shows a failure state on purpose**, and is placed eighth for it. Durability is a real
  differentiator, but *"Couldn't transcribe that recording."* out of context can be read as the app
  not working. It never moves forward in the carousel; if it is ever doubted, drop it.

Frames 5 and 7 must stay tasteful: natural documents that happen to use structure. The moment either
reads as a productivity dashboard, the implementation and the marketing have both gone too far
(RULES.md §7).

**Done 2026-08-29 — the assets are rebuilt; the listing itself is not yet updated.** Every raw was
recaptured against the current build and the ten frames above are composed in `docs/appstore/6.9/`.
What remains is the upload, plus one capture that needs a real iPhone (Share). **Subtitle and keywords
are unaffected**: *Notes, drafts, lists & voice* still describes the app, and no keyword names a
language.

### What's New (per version)

App Store Connect asks for a **What's New** text on every version after the first. It lives in
`docs/appstore/release-notes.md`, one section per submitted version, and it is held to this section's
bar: only capability that is in *that* build, no language list or accuracy claim, and no mention of
the monthly voice allowance — naming a cost boundary in store text turns it into a feature
(`RULES.md` §8).

The current entry is **1.1.0 (build 2)**: Quick Voice from Home, pause/resume, retained recordings,
links, code cards, and per-note Share.

---

## 5. Website

### Title & meta

- **Browser / SEO title:** `As Told — Private Notes, Voice & Writing for iPhone`
- **Meta description:** *A private writing space for iPhone. Write it or say it — multilingual voice
  transcription, headings, lists, tables and code — and keep it on your device.*

Both the root layout default and the homepage's own `pageMetadata` carry the description, and they must
say the same thing. The pre-2026-08-28 line named *English, Telugu or Hindi* in the description on every
page; it is now the multilingual line above (`RULES.md` §7, "Language claims").

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

### Sections — rebuilt 2026-08-28

The page was written for V1 and had gone stale in both directions: it headlined three languages, and it
said nothing about Quick Voice, pause / resume, retained recordings, links, code blocks, preformatted
blocks, or Share — all of which shipped after it was written. Nine sections, in this order:

1. **Hero** — *Anything you want to put into words.* / *Write it. Say it. Keep it.* / private-notes
   descriptor / App Store CTA / current Home capture (which now carries the microphone).
2. **Write or speak** — the two entry points side by side in the Home header. Home → Listening →
   an ordinary note, as three real captures.
3. **Multilingual** — *Speak the way you actually speak.* The capability leads; the tested groups
   follow as a footnote. Two code-switch specimens and two in-app captures.
4. **Writing** — the writing toolbar and the shape vocabulary: six toolbar shapes plus links, tables
   and code, which arrive with your text rather than from a button.
5. **Paste + code** — what survives a paste and what doesn't, then the code card: syntax colour, the
   language label, **Copy Code**, edited in place. One section, two movements — they are one argument.
6. **Reliable voice** — pause / resume, and a retained recording after a retryable failure with
   **Retry** / **Delete Recording**. Deliberately placed **after** voice has been shown working: a page
   that opens on failure UX is selling a defect.
7. **Share** — the system sheet, and nothing of ours around it. **Copy-only, no device**: a
   simulator has no Messages, Mail or AirDrop, so a capture of the sheet would advertise Reminders
   and Save to Files as the only destinations. It stays copy-only until the sheet is captured on a
   device (`website/README.md`, "Known gaps").
8. **Nothing to organize + Your writing isn't an account** — Timeline / Search / Calendar beside the
   privacy promises. Do not market folders. **Never say "Nothing ever leaves your phone"** —
   transcription involves server processing (`RULES.md` §3).
9. **Light / Dark** — the same *note* in both, not the same Home screen.

**Do not market on this page:** iCloud sync & backup, export & restore, reminders, Pro / expanded voice,
the App Intent or Action Button, Siri shortcuts, the voice dictionary, AI self-correction, or generated
titles. None of them ships (`docs/09-v2-roadmap.md`, `docs/10-voice-v2.md` §25).

### Final CTA

```text
[feather]  As Told
Your thoughts. Your words. As told.
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

**Superseded 2026-08-28 — the card is now generated, not painted.** The paragraph above describes the
one-off `gpt-image-2` render. `public/og.png` is rebuilt from `website/scripts/og.html` (`npm run og`),
which composes the brand, the tagline, the headline and the **live `home-light` capture** in real type —
so it is regenerated whenever the Home capture changes rather than being a binary nobody can re-derive.
It was regenerated in this pass, because Home now carries the microphone. The copy is unchanged; the
device inside it is current.

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
- [x] **Live App Store listing wired into the site and the app** (2026-08-26) — `APP_STORE_URL` is
      set, so all three CTAs (header, hero, final) are links; the iOS Safari smart banner is on via
      `itunes.appId`; and "Rate As Told" in the app opens the listing's review sheet
- [x] **Point the `astold.app` DNS at the Vercel project** — done: Vercel nameservers, both hosts
      attached to the `astoldapp` project, every route serving 200
- [x] **Canonicals resolve without a redirect** (2026-08-26) — `www` is the Vercel **primary**, so
      the apex 308s to it; `SITE_URL` named the apex, which made every canonical, `og:url` and
      sitemap entry point at a URL that redirects. `SITE_URL` is now `https://www.astold.app`.
      The apex redirect stays, so older links keep working
- [x] Audit alt text — every screenshot carries a descriptive alt; only the brand mark and the CTA
      feather are `alt=""`
- [ ] Capture a blank-editor shot and a dark-editor shot (see `website/README.md` § Known gaps)
- [x] **Support contact for App Store Connect** — `krishnasathvikm@gmail.com`. This satisfies the
      contact App Review requires, and it is deliberately **not** published on the site: it is a
      personal mailbox, and a plain-text address on a crawled page is scraped within days.
      `SUPPORT_EMAIL` in `website/lib/site.ts` therefore stays `null`, and `/support`, `/privacy`
      and `/terms` keep the self-service answer (the FAQ, plus the app's own Writing help).
      The public **Support URL** on the listing is `https://www.astold.app/support`.
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
