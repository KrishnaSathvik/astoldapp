# App Store screenshots — 6.9"

Ten submission-ready iPhone screenshots at **1320 × 2868**, plus one composed alternate. RGB, no
alpha, no colour profile.

> **Size note.** Apple's 6.9" slot accepts 1290 × 2796, 1320 × 2868, and 1260 × 2736. The
> **1284 × 2778** and 1242 × 2688 sizes are the older **6.5"** set. These are built at 1320 × 2868 —
> iPhone 17 Pro Max native, so the UI is captured 1:1 with no resampling.

**Rebuilt 2026-08-29 for V2.** The previous eight told the V1 story with raws taken 2026-08-21 —
before Quick Voice, pause/resume, retained recordings, links, code blocks and Share shipped — and
frame 5 headlined *"Telugu. Hindi. English."*, which is the benchmark set, not the product boundary
(`RULES.md` §7, "Language claims"). Ten frames now, which is Apple's maximum:

| # | File | Screen | Headline | Support |
|---|---|---|---|---|
| 1 | `01-words` | Home, `+` and mic in the header | Anything you want to put into words. | Write it. Say it. Keep it. |
| 2 | `02-voice` | Quick Voice, cropped to the timer (dark) | Write it. Or just say it. | Tap the mic and talk. There is no note to create first. |
| 3 | `03-languages` | Telugu ↔ English note | Speak the way you actually speak. | Switch languages mid-sentence. Your words stay in the language you used. |
| 4 | `04-pause` | In-note recorder, paused | Pause. Think. Keep going. | A recording waits while you find the next sentence. |
| 5 | `05-structure` | Toolbar detail crop | Structure without the complexity. | Headings, lists and checklists. No block picker. |
| 6 | `06-code` | SQL card (dark) | Code that still looks like code. | Syntax colour, monospaced, and Copy Code. |
| 7 | `07-paste` | Pasted note + table lens | Paste it. Keep the structure. | Headings, lists and tables arrive intact. |
| 8 | `08-durable` | Retained recording, Retry / Delete | Your words shouldn't disappear. | A dropped connection never costs you the recording. |
| 9 | `09-find` | Bento: Home + Calendar + Search | Find it again. | Search what you remember. Or start with the day. |
| 10 | `10-privacy` | App lock / Face ID | Private by default. | No account. Your notes stay on your iPhone. |
| — | `alt-daynight` | Same note, light + dark | Yours, day or night. | *composed, not shipped* |

The first three carry the most weight: they can appear directly in search results, and most people
never swipe past them. **Frame 1 now leads with Home rather than the editor** — a reversal of the
V1 decision, and deliberate: Home is where `+` and the microphone sit side by side, which is the
whole of the V2 story in one frame.

### Two frames that need a decision before submission

- **There is no Share frame, and one cannot be captured from a simulator.** `-openShare` presents the
  real sheet, but a simulator has no Messages, Mail or AirDrop, so it offers Reminders and Save to
  Files — a frame implying those are the destinations is worse than no frame. Capture it on a device;
  the carousel is already at ten, so it displaces one. `alt-daynight` is composed and unshipped for
  exactly that swap.
- **Frame 8 shows a failure state.** *"Couldn't transcribe that recording."* in a store screenshot is
  a real risk: out of context it can be read as the app not working, and it is the one frame that
  could be quoted against the product. It earns its place — durability is a genuine differentiator
  and no competitor shows it — but it is placed **eighth**, well past the frames that sell, and the
  headline does the framing. Drop it rather than move it forward.

## Composition

Deliberately varied, one shared type and colour system:

- **1, 5, 7** — full device, straight on, no tilt.
- **2** — charcoal ground, breaking the carousel rhythm midway.
- **3** — device plus a ~1.6× lens over the table. The lens sits *on* the region it magnifies; placed
  anywhere else it reads as a duplication bug rather than a detail.
- **4** — oversized bezel-free UI crop. No side bleed: scaling past the canvas clipped the list markers.
- **6** — bento. One large phone, a calendar card, and a search strip crossing the phone's lower edge.
- **8** — two overlapping devices, light in front of dark, over a charcoal night panel. Side-by-side
  crops were tried first and rejected: they severed sentences mid-line, which looks like a defect.
  Occlusion reads as depth instead.

Palette: warm paper `#F6F2E9`, soft chalk `#FBFAF7`, soft stone `#EEECE7`, charcoal `#1A1A1C`,
ink `#1C1C1E`, muted blue-gray accent `#314D63` (the app's own `Accent`).

No app icon and no App Store badge inside any frame — the icon already sits above the carousel, and
Apple's asset guidance advises against store references, prices, and URLs in screenshots.

## Measured

Re-measured 2026-08-29 across all eleven composed frames:

| Check | Requirement | Result |
|---|---|---|
| Canvas | 1320 × 2868, RGB, no alpha | all eleven |
| Largest empty band | ≤ 22% of canvas height | 7.8–18.1% |
| Headline contrast | WCAG AA 4.5:1 | 15.2 paper · 16.3 chalk · 14.4 stone · 15.5 charcoal |
| Support contrast | WCAG AA 4.5:1 | 6.0 paper · 6.5 chalk · 5.7 stone · 7.2 charcoal |
| Headline lines | ≤ 3, 2 preferred | 1–2 |

Re-measure after any layout change; every defect found so far was caught by measuring, not by eye —
including this pass's worst one. Frame 2 was first composed as a **crop** of the Quick Voice screen,
which measured a **40% empty band**: that screen is deliberately near-empty, and cropping it removed
the one thing that explained the emptiness. Shown as a whole phone it reads as a device that is
listening, and measures 8.6%.

Two fixes in the type this pass, both worth keeping:

- **The accent rule clears the glyph box, not the line advance.** `size * 1.02` is tighter than New
  York's ascent + descent, so a rule placed off the advance ran through the descender of *"actually
  speak."* and read as an underline on the "y". It is now placed at `ascent + descent` below the last
  line's top, which is where the line actually ends whatever it ends with.
- **`wrap()` honours a literal `\n`.** Greedy wrapping broke *"Write it. Or just say it."* after
  "Or". A four-word headline is copy, not a paragraph — where it breaks is a design decision, and the
  frame states it.

## How these are built

Real UI, real type. The marketing layer never redraws a pixel of the product.

1. **App UI** — `simctl` capture at native resolution via the `DebugLaunch` flags in
   `App/DebugSupport.swift`, composited untouched.
2. **Type** — New York, the brand serif (`Core/DesignSystem/AppMark.swift`), over SF.

   > **Pin the Optical Size axis.** New York's `opsz` runs 12–256 and **defaults to 256**, a poster
   > grade whose crossbars thin to hairlines — at that setting "Hindi" renders as "I Iindi" and
   > "Telugu" as "Tclugu", and the headline stops matching the wordmark the app itself draws.
   > `compose.py` pins `opsz=40`. The serif is also much wider at a text optical size, so a fixed
   > headline size overflows and orphans the last word — hence the auto-fit against a line budget.
3. **Background** — flat paper with a whisper of depth, generated in `compose.py`.

### Recapture

Install a **Debug** build (the flags are `#if DEBUG`). Set the marketing status bar once:

```sh
xcrun simctl status_bar <device> override --time "9:41" \
  --batteryState discharging --batteryLevel 100 \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4
```

`capture.sh` in this folder does every shot in order — `bash docs/appstore/capture.sh`, then
recompose. It encodes the flags below, with the shared
`-hasCompletedWelcome YES -voiceTranscriptionConsent YES -appTheme light|dark`. Seed and open are
**separate launches**, and the script terminates between every shot.

| Raw | Extra flags |
|---|---|
| `01-hero` | `-resetStore -seedSampleNotes` |
| `11-search` | `-resetStore -seedSampleNotes -searchQuery Alaska` |
| `12-calendar` | `-resetStore -seedSampleNotes -openCalendar` |
| `06-lock` | `-resetStore -seedSampleNotes -forceLocked` |
| `20-quickvoice` / `21-quickvoice-dark` | `-openQuickVoice` (light / dark) |
| `02-structure` / `13-seattle-dark` | seed `-seedSeattleDemo`, then `-openSeededNote` (light / dark) |
| `10-editor-toolbar` | same store, `-openSeededNote -caretAtEnd` |
| `22-voice-paused` | same store, `-openSeededNote -autoStartVoice -voiceAutoPause` |
| `23-retry` | same store, `-openSeededNote -autoStartVoice -voiceFakeFailure` |
| `05-paste` | `-resetStore -seedBudgetDemo` then `-openSeededNote` |
| `24-code` / `25-code-dark` | `-resetStore -seedQueryDemo` then `-openSeededNote` (light / dark) |
| `04-multilingual` | `-resetStore -seedVoiceDemo` then `-openSeededNote` |
| `26-hindi` | `-resetStore -seedHindiDemo` then `-openSeededNote` |

### The raw library (added 2026-08-29)

Twelve further raws, numbered from 30, captured **as source material rather than as frames**. Nothing
in `compose.py` reads them yet. The brief was a library of *believable* screens — notes a person could
plausibly have written — so a shipped frame can be chosen from a shelf instead of captured to order.

| Raw | Screen | Flags (after the shared `-hasCompletedWelcome YES -voiceTranscriptionConsent YES -appTheme …`) |
|---|---|---|
| `30-home-library` | Home, seven notes with distinct names | `-resetStore -seedShowcaseNotes` |
| `31-quickvoice-listening` | Quick Voice, **00:17**, waveform moving | `-openQuickVoice -voiceDemoLevels` |
| `32-voice-multilingual` | A spoken note that changes language mid-note | seed `-seedWeekendThoughtsDemo`, then `-openSeededNote` |
| `33-structure-alaska` | Heading, subheading, bullets, numbers, checklist **and** a link, all on one screen | seed `-seedAlaskaDemo`, then `-openSeededNote` |
| `34-code-sql` / `39-code-sql-dark` | SQL card with prose above *and below* it | seed `-seedSQLDemo`, then `-openSeededNote` (light / dark) |
| `35-table-japan` | A three-row table with words and a link around it | seed `-seedJapanDemo`, then `-openSeededNote` |
| `36-paste-architecture` | A preformatted diagram — `Plain text` / `Copy Text`, visibly not code | seed `-seedArchitectureDemo`, then `-openSeededNote` |
| `37-voice-recovery` | Retained recording, Retry / Delete, over an ordinary note | same store as `42`, `-openSeededNote -autoStartVoice -voiceFakeFailure` |
| `40-quickvoice-paused` | Quick Voice, **00:18**, Paused / Resume | `-voicePauseAfter 18 -openQuickVoice -voiceAutoPause -voiceDemoLevels` |
| `41-note-voice` | The in-note recorder over a structured note, **00:15**, still listening | same store as `33`, `-openSeededNote -autoStartVoice -voiceHold -voiceDemoLevels` |
| `42-writing-sunday` | An ordinary note. No code, no table, no gimmick | seed `-seedSundayDemo`, then `-openSeededNote` |

Three things this set had to solve, all of which are now flags rather than luck:

- **A silent simulator draws a dead waveform.** There is no audio input, so `AVAudioRecorderService`
  reports the floor and `WaveformView` renders a straight dashed line — a picture of a recorder that
  is hearing nothing, which is the opposite of the point. `-voiceDemoLevels` swaps in the DEBUG
  stand-in recorder (real file, real state machine, real view) with a speech-shaped level. It changes
  what the *microphone* reports and nothing else; every period in the shape is shorter than the
  waveform's own 3.2 s window, because a slower one fills the strip with one slope and reads as a
  ramp. **On a device, capture without it.**
- **A timer at `00:01` reads as staged.** The clock is the recorder's own elapsed time, so the wait
  *is* the number — `31` waits 16 s. Pausing needed the same freedom: `-voicePauseAfter <seconds>`
  now sets what `-voiceAutoPause` had hard-coded at 1.5 s, so `40` freezes at `00:18`.
- **The in-note recorder auto-finished after 1.5 s.** `-voiceAutoPause` was the only way to hold it,
  which meant the *recording* state could only be captured paused. `-voiceHold` suppresses the
  auto-Done and leaves it listening.

Two notes on what the library does *not* contain:

- **`38-share-sheet` is missing, and cannot be produced here.** `-openShare` was run against
  `42-writing-sunday`: the sheet presents correctly, with the As Told feather and *"Ideas for Sunday"*
  at the top — and then offers **Reminders**, **More** and **Save to Files**, because a simulator has
  no Messages, Mail, AirDrop or WhatsApp. The capture was taken, inspected and deleted rather than
  filed, since a frame implying those are the destinations is worse than no frame. Device only.
- **The multilingual note is romanised, not scripted.** `32` code-switches through romanised Telugu
  and Spanish, which is how a great many people actually write — but it shows one script, so it is
  weaker *visual* evidence than `04-multilingual` (Telugu) or `26-hindi` (Devanagari). It is also the
  only raw touching a language outside the benchmark set of `RULES.md` §1. Neither is a copy problem
  on its own — the rule binds claims, and the frames name no language — but if a composed frame ever
  headlines this one as evidence, read §7 "Language claims" first.

**Three raws are captured but composed into nothing**, on purpose: `20-quickvoice` (the light Quick
Voice screen), `24-code` (the light SQL card) and `26-hindi` (the Devanagari note). The shipped frames
use the dark variants and the Telugu note; these are the library the user asked for, so a frame can be
re-grounded light, or the multilingual frame swapped to Hindi, without another capture session.

The voice raws are the ones with teeth:

- **`-openQuickVoice` and `-voiceAutoPause` exist for these captures** (added 2026-08-28). Quick Voice
  lives behind a tap on Home and neither flag finishes on a timer, so the state holds as long as the
  capture needs. `14-voice-dark` — the old raw, grabbed ~2 s into an `-autoStartVoice` run before it
  auto-finished — is **retired**: it was always racing a 1.5 s clock, and a late grab silently
  captured the *failure* state instead of the recorder.
- **`23-retry` is that failure state, on purpose.** `-voiceFakeFailure` swaps in the stand-in
  transcription that always fails the way a dropped connection does, so the retained-recording surface
  is the real one, driven by the real `VoiceCaptureModel`.

Three traps worth knowing:

- **Nothing else may touch the simulator while `capture.sh` runs.** Not a UI test, not a website
  capture. A concurrent `simctl launch` reseeds the store underneath a shot, and you get a screenshot
  of somebody else's note — verified the hard way on 2026-08-28, when a `-seedSeattleDemo` capture
  came back holding the table demo a test had just seeded. `pgrep -fl xcodebuild` will **not** catch a
  capture script; check `pgrep -f simctl` too.

- **Argument order matters.** NSUserDefaults parses `-key value` pairs, so bare `DebugLaunch` flags
  interleaved with them can swallow a value — `-hasCompletedWelcome YES` silently fails and you get
  the Welcome screen. Put the pairs first and `-searchQuery <term>` last.
- **The software keyboard will not raise** on a headless simulator, so the editor captures show the
  floating toolbar without a keyboard. That is the better frame anyway: a keyboard would cover the
  structured content these screenshots exist to show.
- **The editor caption shows the note's own creation time**, so a demo note created at the moment of
  capture puts a second, different clock in the frame — a 9:41 status bar above an
  "AUGUST 21, 2026 · 22:31" caption, which reads as a product bug rather than a capture one. Every
  single-note seed is pinned to `DebugLaunch.demoNoteDate` (today at 9:41) so the two agree. It
  agrees in both hour cycles too: a 24-hour simulator renders "09:41", a 12-hour one "9:41 AM" — and
  a fixed `dateFormat` of `h:mm a` does **not** pin the cycle, iOS overrides it from the device's
  24-Hour Time toggle. Recapture after this change; earlier raws still carry the old stamp.

### Recompose

```sh
python3 docs/appstore/compose.py     # reads raw/, writes 6.9/
```

Every frame's headline, support, alignment, and composition lives in the `SHOTS` list at the bottom.

## Optional: generated background plates

Drop a 1320 × 2868 image at `plates/<name>.png` and that frame uses it as its background. Plates stay
*backgrounds only*: the app UI and all type composite on top afterwards, so a model never draws
interface or lettering. That guarantee matters most on frame 5 — Telugu and Devanagari come back as
broken glyphs from image models, and here the script is the real thing rendered by the app.

## Copy compliance

Checked against `RULES.md` §7 and `docs/08-positioning-marketing.md` §0:

- **No frame names a language.** Frame 3 headlines the capability — *"Speak the way you actually
  speak."* — and the Telugu ↔ English note underneath is the evidence. The retired frame 5 headlined
  *"Telugu. Hindi. English."*, which stated the benchmark set as though it were the product boundary
  (`RULES.md` §7, "Language claims"). Nothing here says "all languages" or counts them either.
- Structure, paste and code claims (5, 6, 7) are allowed: all three ship. Frame 6 claims syntax
  colour, monospacing and **Copy Code**, which is exactly what the card draws — no claim that As Told
  runs, lints, or completes code.
- Frames 2 and 4 describe Quick Voice and pause/resume, both shipped (`docs/10-voice-v2.md` §2). No
  frame implies on-device transcription.
- Frame 8 shows a real failure state with real copy. The message is the `.offline` one — *"A
  connection is needed to transcribe this recording."* — which reads as a network condition rather
  than a defect, and the frame's own headline does the framing.
- Frame 10 avoids the banned "Nothing ever leaves your phone", and the **old open nit is closed**:
  "Local by default" (which implied a non-local option exists) is now *"Your notes stay on your
  iPhone."* No encryption claim anywhere — app lock is an access gate.
- No pricing, no URLs, no competitor comparisons, no third-party logos.

## Reconciled with the positioning doc

`docs/08-positioning-marketing.md` §4 previously specified a **nine**-shot V1 sequence that this
folder never matched. Both were rewritten together on 2026-08-29 and now describe the same ten
frames; the doc owns the story, this file owns the mechanics. Change one, change the other.
