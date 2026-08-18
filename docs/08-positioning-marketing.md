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

### Subtitle — gated on the editor shipping

- **Now (plain-text editor):** keep the current narrower subtitle. Do **not** publish structured-writing
  claims before the feature ships.
- **After the broader editor ships:** move to **"Notes, drafts, lists & voice"** (28 chars) — communicates
  notes, long-form drafts, lists, and voice while leaving the brand name clean.

### Keywords (once the new subtitle ships)

Don't repeat terms already in name/subtitle (notes, drafts, lists, voice). Suggested hidden set (~97
ASCII bytes):

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

### Screenshots (update only once the broader editor ships)

1. *Anything you want to put into words.* — Home (support line: "Thoughts, notes, drafts, lists, and more.")
2. *Just start writing.* — clean long-form Editor.
3. *Or just say it.* — recording state.
4. *Your voice becomes your page.* — transcript inserted into writing.
5. *Write more than thoughts.* — tasteful long-form + bullets + checklist (**not** a productivity dashboard).
6. *Speak the way you speak.* — Telugu+English or Hindi+English.
7. *Find it the way you remember it.* — Search.
8. *Remember the day?* — Calendar.
9. *Your writing stays yours.* — Face ID / privacy.

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

- Copy: **As Told** / *Anything you want to put into words.* / **WRITE IT. SAY IT. KEEP IT.**
- Visual: warm ivory canvas, abstract feather, one premium iPhone (Home or Editor), no clutter — not a
  feature collage. Only show structure (draft/checklist) on the device once it actually ships.

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

`/` · `/privacy` · `/support` · `/voice-notes` · `/private-notes` · `/multilingual`. Later, and only
after the matching feature ships: `/writing-app` · `/telugu-voice-to-text` · `/hindi-voice-to-text` ·
`/speech-to-text-notes` · `/checklists`. Do not generate dozens of shallow keyword pages.

### Technical checklist

Unique `<title>` and meta description per page · one clear H1 · canonical URLs · `robots.txt` · sitemap ·
crawlable internal links · meaningful alt text · descriptive screenshot filenames · Open Graph + social
preview image · mobile performance · semantic HTML · JSON-LD only where the type genuinely applies.

---

## 7. North star

> **As Told — Write it. Say it. Keep it.**
> A private place for anything you want to put into words.

The long-term differentiation is not "another notes app with voice transcription." It is **a writing
space where your hands and your voice can create the same page** — and the boundary that is never crossed:
**As Told can help structure your words; it must never replace your words.**
