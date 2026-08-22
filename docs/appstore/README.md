# App Store screenshots — 6.9"

Eight submission-ready iPhone screenshots at **1320 × 2868**. RGB, no alpha, no colour profile.

> **Size note.** Apple's 6.9" slot accepts 1290 × 2796, 1320 × 2868, and 1260 × 2736. The
> **1284 × 2778** and 1242 × 2688 sizes are the older **6.5"** set. These are built at 1320 × 2868 —
> iPhone 17 Pro Max native, so the UI is captured 1:1 with no resampling. Apple allows up to 10
> screenshots; eight is deliberate.

| # | File | Screen | Headline | Support |
|---|---|---|---|---|
| 1 | `01-write` | Structured editor + writing toolbar | Write it. Say it. Keep it. | Private notes, in your own words. |
| 2 | `02-voice` | Recording state (dark) | Or just say it. | Your words return right where you left off. |
| 3 | `03-paste` | Pasted note + table lens | Paste it. Keep the structure. | Headings, lists and tables arrive intact. |
| 4 | `04-structure` | Toolbar detail crop | Structure when you need it. | Headings, lists and checklists. Nothing more. |
| 5 | `05-languages` | Telugu ↔ English note | The mix stays the mix. | Telugu. Hindi. English. Together when you want them. |
| 6 | `06-find` | Bento: Home + Calendar + Search | Find it again. | Search what you remember. Or start with the day. |
| 7 | `07-privacy` | App lock / Face ID | Your notes stay yours. | No account. Local by default. Face ID when you want it. |
| 8 | `08-daynight` | Same note, light + dark | Yours, day or night. | — |

The first three carry the most weight: they can appear directly in search results, and most people
never swipe past them. Frame 1 leads with the **editor**, not Home — the product is the writing surface.

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

| Check | Requirement | Result |
|---|---|---|
| Canvas | 1320 × 2868, RGB, no alpha | all eight |
| Largest empty band | ≤ 22% of canvas height | 8.1–18.8% |
| Headline contrast | WCAG AA 4.5:1 | 15.2 (light), 15.5 (dark) |
| Support contrast | WCAG AA 4.5:1 | 6.0 (light), 7.2 (dark) |
| Headline lines | ≤ 3, 2 preferred | 1–2 |

Re-measure after any layout change; every defect found so far was caught by measuring, not by eye.

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

`capture.sh` in this folder does all ten shots in order — `bash docs/appstore/capture.sh`, then
recompose. The table below is what it encodes, per shot, with the shared
`-hasCompletedWelcome YES -voiceTranscriptionConsent YES -appTheme light|dark`:

| Raw | Extra flags |
|---|---|
| `10-editor-toolbar` | `-resetStore -seedSeattleDemo -openSeededNote -caretAtEnd` |
| `14-voice-dark` | `-resetStore -seedSeattleDemo -openSeededNote -autoStartVoice` (theme dark) — grab **~2 s in**; later and the empty simulator recording fails to transcribe |
| `05-paste` | `-resetStore -seedBudgetDemo -openSeededNote` |
| `04-multilingual` | `-resetStore -seedVoiceDemo -openSeededNote` |
| `01-hero` | `-resetStore -seedSampleNotes` |
| `12-calendar` | `-resetStore -seedSampleNotes -openCalendar` |
| `11-search` | `-resetStore -seedSampleNotes -searchQuery Alaska` |
| `06-lock` | `-resetStore -seedSampleNotes -forceLocked` |
| `02-structure` / `13-seattle-dark` | `-resetStore -seedSeattleDemo -openSeededNote` (light / dark) |

Two traps worth knowing:

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

- Structure and paste claims (3, 4) are allowed — `docs/08-positioning-marketing.md` §116 records the
  gate as satisfied: structured writing ships in the editor milestone.
- Frame 2 says words "return right where you left off" — cursor insertion, per `docs/04`. It does not
  imply on-device transcription.
- Frame 7 avoids the banned "Nothing ever leaves your phone". No encryption claim anywhere: app lock is
  an access gate (`RULES.md` §274).
- **Open nit:** frame 7's "Local by default" can be read as implying a non-local option exists. There
  is none — no sync, no cloud copy. "Notes stay on your iPhone" would be tighter.
- No pricing, no URLs, no competitor comparisons, no third-party logos.

## Divergence from the 9-shot plan

`docs/08-positioning-marketing.md` §4 specifies a **nine**-shot sequence. This set is eight and now
overlaps it closely — the doc's "clean editor" and "several documents side by side" are folded into
frames 1 and 4. Reconcile the two before submitting if the doc is meant to stay authoritative.
