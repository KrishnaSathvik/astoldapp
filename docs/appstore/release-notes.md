# Release notes — App Store versions

The **What's New** text App Store Connect asks for on every version after the first, plus what each
version actually contained. One section per submitted version, newest first.

Rules that apply to every entry:

- **Only shipped capability.** The same bar as the listing description (`docs/08-positioning-marketing.md`
  §4): remove any claim about a capability until it is in the build being submitted.
- **No language list, no accuracy claim, no language count** (`RULES.md` §7, "Language claims").
- **No usage meter, credit count, or upgrade call to action** — the monthly voice allowance is a cost
  boundary, not a feature, and naming it in the store text turns it into one (`RULES.md` §8).
- Plain text. App Store Connect renders no markdown, and the field caps at 4000 characters.

---

## 1.2.0 (build 3)

`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` live in `project.yml`; the `.xcodeproj` is generated
from it, so bump it there and re-run `xcodegen generate`. Bumped 2026-09-01.

**What's New — text for submission** (907 characters, cap 4 000):

```text
Home is easier to scan, and the calendar shows you your month.

A clearer Home
Notes are grouped into Today and the previous seven days, with a two-line preview under each title — titled and untitled notes side by side. Show all opens a busy group; Browse older notes takes you to the complete timeline.

A calendar that shows where you wrote
Dots under each day show how much you wrote that day. Tap a day and its notes appear right under the month — go back by when, not just by what.

Checklists, drawn as circles
A checklist item now has a circle beside it. Tap it to tick it off; it stays where you put it.

Steadier voice
A recording that is interrupted is finished properly before anything is sent, and when transcription can't start, the message says what actually happened.

Quieter in Light and Dark
A neutral palette across the app, so the only colour on the page is the one that means something.
```

**What the build contains** beyond 1.1.0: the recent-library Home (Today / Previous 7 Days, capped
groups with `Show all N`, `Browse older notes` → All Notes, two-line flattened previews, no card per
note); the calendar's density dots and the selected day's notes under the month; circular checklist
markers in the editor and `○` / `✓` in previews; the neutralised palette (`groupedCanvas`,
`separator`, `calendarAccent`, `iconVoice`); the recorder-lifecycle work (an unexpected stop is not a
completed recording; finalisation before upload; route observations are not proof the microphone is
gone); attestation failures reported as what they are, in copy and in the relay log; the DEBUG-only
`AppClock` pin and canonical seed library used for the screenshot capture. Marketing assets for this
build: `docs/appstore/raw/library/`.

1.1.0 (build 2) was reviewed and approved before this bump, so the text above describes only what
is new since it — nothing from the entry below is repeated.

---

## 1.1.0 (build 2) — approved

**What's New — submitted text** (1 032 characters, cap 4 000):

```text
Speaking is now as quick as writing.

Say it from Home
The microphone sits beside + on Home. Tap it and talk — there is no note to create first. When your words come back, they become an ordinary note like any other.

Pause. Think. Keep going.
A recording waits while you find the next sentence, then picks up where you left off.

Your words shouldn't disappear
If a recording can't be transcribed — no signal, a connection that dropped — it is kept on your iPhone so you can try again. Nothing you said is thrown away because the network wasn't there.

Links that open
A web address in a note is tappable while you read it, and stays plain text while you edit it.

Code that still looks like code
Paste code and it arrives as a card: monospaced, syntax coloured, with the language named and Copy Code one tap away.

Share a note
A note now has a Share button. It opens your iPhone's own share sheet, so a note goes wherever you already send things.

As always: no account, nothing to sign in to, and your notes stay on your iPhone.
```

**What is in the build.** Voice V2 Phases 1–2 (`docs/10-voice-v2.md` §25 rows 1–4) and V2 roadmap
Phases 1–2 (`docs/09-v2-roadmap.md`):

- Quick Voice from the Home header — voice creates a note, not only writes into one.
- Pause / resume, with the 5-minute cap summing across pauses.
- Retained recordings: a retryable failure keeps the audio for 24 hours behind an explicit Retry,
  with Delete Recording alongside it.
- Links inside `body`, read back but never written over the writer's characters.
- Code blocks: fenced source while editing, a labelled and syntax-coloured card while reading.
- Per-note Share through the system share sheet, and the editor header that carries it
  (Back · date · Share).

Deliberately **not** named in the text above, though it is in the build: the monthly voice allowance
(`RULES.md` §8) and the recording cap moving from 10 minutes to 5.

**Before submitting:**

- Screenshots are rebuilt for this version — `docs/appstore/6.9/`, ten frames, `docs/appstore/README.md`
  is the operational truth. The Share frame still needs a device capture and displaces one frame when
  it arrives.
- Listing description sections were rewritten for V2 (`docs/08-positioning-marketing.md` §4) and the
  listing itself has not been updated yet.
- Subtitle and keywords are unchanged and need no edit.
- Export compliance is answered in the build (`ITSAppUsesNonExemptEncryption = false`), so App Store
  Connect will not ask again.
- Relay must be running with `APP_ATTEST_REQUIRED=true` and a durable `APP_ATTEST_DB_PATH`
  (`RULES.md` §8, `transcription-service/DEPLOY.md`).

---

## 1.0.0 (build 1)

First submission. Approved 2026-08-26 — Apple ID `6804007726`. No **What's New** text: App Store
Connect does not ask for one on a first version.
