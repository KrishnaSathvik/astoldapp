# As Told website — v9

The marketing site for **As Told**, as a Next.js App Router application deployed on Vercel.
It replaced the hand-written static pages (v8) on 2026-08-20: one design system, one header,
one footer, no duplicated page markup.

```sh
npm install
npm run dev        # http://localhost:3000
npm run build      # every route prerenders to static HTML
npm run typecheck
```

## Routes

| Route | What it is |
|---|---|
| `/` | The product story: hero → write or speak → voice → writing → paste & code → share + privacy → light/dark → CTA |
| `/voice` | How voice capture works, end to end — six sections |
| `/languages` | A search landing page for multilingual voice: a hero, three principles, the accuracy note. **Nothing on the site links to it** — see "Language framing" below |
| `/privacy` | The privacy document |
| `/support` | FAQ, grouped: writing, paste, voice, privacy & storage, recovery |
| `/terms` | The terms document |

Primary navigation is **Voice**, plus the CTA — one link, one row, at every width.

It was `Product · Voice · Privacy · Support` until 2026-08-29. The wordmark already is Product, and
Privacy, Support and Terms are utility destinations the footer has carried the whole time; a header
that repeats them opens every page — the legal ones included — with a site directory instead of a
product. `Voice` stays because it is the only secondary page that is *product*, and it is the half
of As Told a visitor cannot see from the homepage's first screen.

`Multilingual` was a top-level item until 2026-08-29 as well; how voice treats languages is a
property of voice, not a fourth thing the product is, so `/languages` keeps its URL and its place in
the sitemap, is reached from neither `/` nor `/voice`, and is linked only from the Support answer
that names the tested groups.

Old URLs are redirected permanently in `next.config.ts` — `/voice-notes` → `/voice`,
`/multilingual` → `/languages`, `/private-notes` → `/privacy`, and the `.html` spellings of
each (Vercel's old `cleanUrls` published both). `/private-notes` is retired as a page: its
subject was privacy, and that content now lives on `/` and `/privacy`.

## Three rules for this site

1. **Light theme only.** The site does not follow `prefers-color-scheme`; there is a single
   palette in `app/globals.css`, taken from the app's own light tokens
   (`docs/03-design-system.md` §15) so the site and the product read as one thing. The app's
   *dark mode* still appears on the page — as a screenshot in the Light/Dark section — because
   that is product content, not site chrome.

2. **Every screenshot is the real app, at its current capability.** No mockups, no illustrated
   UI, and no screenshot older than the feature it illustrates. The `og.png` social card is
   composed around a real capture too.

3. **No contact detail the project does not have, and no circular substitute either.** There is
   no mailbox on `astold.app`, so no page prints one — and no page tells the reader to go and
   find a contact somewhere else, which is what the old line ("use the support contact provided
   with As Told on the App Store listing") did to someone who was already here. Support,
   Privacy, and Terms all render `<SupportContact>`, which points at the two things that do
   answer immediately: the FAQ, and the app's own Writing help.

   `SUPPORT_EMAIL` in `lib/site.ts` stays `null` **on purpose**, not for want of an address:
   App Store Connect has a support contact (recorded once, in
   `docs/08-positioning-marketing.md`), but it is a personal mailbox, and setting the constant
   would print it in plain text on three crawled pages. The listing's public support surface is
   the `/support` URL, which is what that field is for. Set the constant when there is a real
   mailbox on `astold.app`, and all three pages become a `mailto:` at once.

4. **Nothing here imitates an Apple control.** The CTA is typographic. It used to pair a
   hand-copied Apple logo path with the words "Coming to the App Store", which is a counterfeit
   of a system badge; the SVG is gone, and so is that wording — the app shipped. Every CTA is a
   plain link to the listing, and only Apple's own supplied badge asset may replace the text.

## Architecture

```
app/                 one route per directory; every page is statically prerendered
  layout.tsx         header, footer, metadata defaults, reveal observer
  globals.css        design tokens + shared primitives (.wrap, .lede, .eyebrow, .textlink)
  page.tsx           homepage
  <route>/page.tsx   plus a page.module.css when a route needs its own composition
  sitemap.ts         generated /sitemap.xml
  robots.ts          generated /robots.txt
components/          shared building blocks, each with its own CSS module
lib/site.ts          canonical URL, nav, App Store listing, support contact, metadata helper
public/              screenshots, icons, og.png, site.webmanifest
```

Only three components ship JavaScript: `SiteHeader` (the sticky/scrolled state), `RevealObserver`
(the fade-in), and `DocLayout` (the table of contents' active heading). Everything else is a server
component. `LanguageSwitcher` and `LanguageExample` were deleted on 2026-08-29 with the tabbed
language specimens they existed for.

### Things worth knowing before you edit

- **Spacing comes from tokens.** `--section`, `--section-tight`, `--block`, `--wrap`,
  `--measure`. Sections must not invent their own vertical rhythm; that is what made v8 feel
  like a stack of unrelated documents.
- **Section tone alternates.** `<Section tone="plain|warm|deep">` is what gives the page its
  rhythm. `FinalCTA` paints `--bg-deep`, so the section directly above it should not.
- **A screenshot is evidence, so nothing may crop, mask, fade, or overlap one.** This was
  tried and reverted: a bottom fade on split-section devices was destroying ~30% of five
  captures — including the numbered list in the structured-note capture, the one image whose whole
  job is proving the editor does structure — and a −34px overlap in the device pair was covering the
  calendar's back button, its weekday header, and its entire Sunday column. If a device makes
  a section too tall, use a smaller `size` or write a fuller copy column. Never hide app UI.
- **Device sizes** are `sm` 300px / `md` 336px / `lg` 400px / `xl` 460px, set as `--device-w`.
  Every one went up a step on 2026-08-29: a 268px device on a 1440px screen is a thumbnail whose
  UI cannot be read, which defeats the only reason a screenshot is on the page. At `lg` a 1206×2622
  capture now renders 869px tall; that is what a section beside it has to accommodate. `PhoneShot`
  declares the intrinsic size and the `sizes` attribute once — update them there if the capture
  device ever changes.
- **`PhonePair stagger`** steps the second device *down* (72px), never sideways.
- **`PhoneFigure` needs its size class on the `<figure>` too** — a flex item with no width
  collapses to nothing until its image loads.
- **Never lock `body` overflow.** `<html>` is the scroll port here; hiding body's overflow makes
  body a scroll container and the sticky header stops sticking.
- **The App Store CTA** links to the live listing. `APP_STORE_URL` in `lib/site.ts` is the only
  place the store is named — change it there and all three CTAs follow — and `APP_STORE_ID` beside
  it feeds the iOS Safari smart banner (`itunes.appId` in `app/layout.tsx`). There is no pre-launch
  state any more: the constant is not nullable, and the "Coming to the App Store" span and its
  `.pending` style were deleted when the app shipped.
- **Language framing: name no language outside the Support answer.** `RULES.md` §7 ("Language
  claims") is binding on this site, and was tightened on 2026-08-29 because the previous pass
  changed the words and left the framing. The public claim is the capability — *multilingual voice
  transcription*, *speak naturally across languages*, *no language picker*, *switch naturally*,
  *no forced translation*. The five benchmark groups are named in exactly one place, the Support
  answer for "Which languages can I speak?", and described there as release test groups. They must
  not appear in a hero, a chip or pill row, a tab bar, a `figcaption`, an image `alt`, a feature
  grid, or a CTA. A screenshot of a mixed-language note is welcome; **captioning it "Telugu +
  English" is what made a capability read as a catalogue**, and is what the redesign removed.
  `scripts/audit-shots.mjs` cannot catch this — reading the page can.
- **Never say** "all languages", "every language", a language count, "perfect transcription", or
  "understands any accent". None of those is measured.

## Deploying

The Vercel project must have its **Framework Preset set to Next.js** — it was configured as a
static site for v8. `vercel.json` declares `"framework": "nextjs"`; the redirects and security
headers moved into `next.config.ts`.

## Regenerating the screenshots

Screenshots come out of the simulator via the DEBUG-only launch arguments in
`App/DebugSupport.swift`. Build and install the Debug app, pin the status bar, then drive each
surface:

```sh
SIM=<simulator-udid>
xcodebuild -project Yourly.xcodeproj -scheme Yourly -configuration Debug \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath build/dd-shots build
xcrun simctl install $SIM build/dd-shots/Build/Products/Debug-iphonesimulator/Yourly.app
xcrun simctl status_bar $SIM override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3

T="-appTheme light -hasCompletedWelcome YES"
xcrun simctl launch $SIM com.astold.app $T -resetStore -seedSampleNotes   # home
xcrun simctl launch $SIM com.astold.app $T -searchQuery Seward            # search
xcrun simctl launch $SIM com.astold.app $T -openCalendar                  # calendar
xcrun simctl launch $SIM com.astold.app $T -openSeededNote                # editor
xcrun simctl launch $SIM com.astold.app $T -forceLocked                   # lock
xcrun simctl launch $SIM com.astold.app $T -resetStore -seedVoiceDemo     # then -openSeededNote
xcrun simctl io $SIM screenshot --type=png <name>.png
```

Seeding runs in a `.task` on the root view, so seed and open are **separate launches** —
passing `-resetStore -seed… -openSeededNote` together races and can capture the previous note.

Keep the capture at its native **1206×2622** (iPhone 17 Pro, 3×) and encode it straight to WebP —
`cwebp -q 88 -m 6 -sharp_yuv`. Do **not** downscale first: the library used to be reduced to 720 px
before it reached the site, which is below the 1068 device-pixels an `lg` device asks for on a 3×
display, and Next's image pipeline then had nothing to work with. `PhoneShot` declares 1206×2622 as
the intrinsic size, so the whole library has to agree.

Every file has exactly one job:

| File | Launch arguments | Where it appears |
|---|---|---|
| `home-light` | `-resetStore -seedShowcaseNotes` | `/` hero, `/` Write-or-speak, `/voice`, `og.png` |
| `home-dark` | same store, `-appTheme dark` | (held) |
| `quickvoice-light` | `-openQuickVoice -voiceDemoLevels`, waited to ~00:17 | `/` Write-or-speak, `/voice` hero |
| `quickvoice-paused-light` | `-voicePauseAfter 18 -openQuickVoice -voiceAutoPause -voiceDemoLevels` | `/` Voice, `/voice` Pause and resume |
| `recording-light` | `-openSeededNote -autoStartVoice -voiceAutoPause` | (held) |
| `retry-light` | `-openSeededNote -autoStartVoice -voiceFakeFailure` | `/voice` If something goes wrong |
| `consent-light` | `-openSeededNote -autoStartVoice`, consent **not** granted | `/voice` |
| `structure-light` | `-resetStore -seedSeattleDemo` then `-openSeededNote` | `/` Light/Dark |
| `structure-dark` | same, `-appTheme dark` | `/` Light/Dark |
| `toolbar-light` | same, `-openSeededNote -caretAtEnd` | `/` Writing |
| `table-light` | `-resetStore -seedBudgetDemo` then `-openSeededNote` | `/` Paste |
| `code-light` | `-resetStore -seedQueryDemo` then `-openSeededNote` | `/` Code |
| `note-light` | `-resetStore -seedSundayDemo` then `-openSeededNote` | `/` Write-or-speak |
| `search-light` | `-searchQuery Seward` | (held) |
| `calendar-light` | `-openCalendar` | (held) |
| `lock-light` | `-forceLocked` | (held) |

**`hindi-light` and `voice-light` were deleted from `public/` on 2026-08-29, and no capture
replaces them.** Neither was ever captioned by language and neither `alt` named one — and they were
still the wrong pictures. A note in a particular script *is* the language claim whatever the words
beside it say, and with a Telugu/English note closing the homepage sequence and a Hindi/English one
illustrating the multilingual section, the page taught every visitor that As Told is an English +
Telugu + Hindi app (`RULES.md` §7, "Language claims"). The multilingual argument is carried by the
recording screen now: there is no language control on it, and the absence is the proof.

`note-light` (`42-writing-sunday`, an ordinary English note) took the sequence's closing slot, which
is the better picture for what that step claims — *what you end up with is just a note*. The raw
captures are kept at `docs/appstore/raw/26-hindi.png` and `raw/32-voice-multilingual.png` for
testing; nothing on the site may reference them.

**Nine captures carry the homepage, in ten places**, every one at `lg` or larger. `home-light` is
the only file drawn twice — as the hero, then as the first step of the write-or-speak sequence.
The page showed fourteen devices before 2026-08-29 and eleven after it, several at 268px and nearly
all annotated, which is how a marketing page starts reading as documentation. The library keeps
every held file — a held capture is current, correct, and one section change away from being
wanted.

Four of these need care:

- **`quickvoice-light` / `quickvoice-paused-light`** — Quick Voice lives behind a tap on Home, so
  `-openQuickVoice` exists to present it on launch and `-voiceAutoPause` calls the same `pause()`
  the button calls. Neither finishes on a timer, so the state is held as long as the capture needs.
  Both were replaced on 2026-08-29 by the raw-library pair (`31-quickvoice-listening` /
  `40-quickvoice-paused`): the timer is the recorder's own elapsed time, so **the wait is the number
  on the clock**, and 00:01 over a flat meter read as staged. They are now one recording seen twice
  — 00:17 listening, 00:18 paused — and `-voiceDemoLevels` moves the waveform, because a simulator
  in a quiet room has no input and the real meter draws flat.
- **`recording-light`** — `-autoStartVoice` alone finishes the recording after 1.5s, which no
  screenshot can outrun; `-voiceAutoPause` holds the in-note panel open instead. This capture is
  therefore the **Paused** panel over a real note, and the alt text says so.
- **`consent-light`** — the opposite: it only appears while `voiceTranscriptionConsent` is unset, so
  capture it before granting, or after `xcrun simctl erase`.
- **`toolbar-light`** — the only capture that needs the **software** keyboard, and a Mac with a
  hardware keyboard attached does not raise one. Set
  `defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO`, open Simulator.app so
  the setting takes, capture, then **set it back to YES** — a UI test asserts on `app.keyboards`
  and breaks while it is off.
- **`structure-light` / `structure-dark`** — the Light/Dark pair must be the same note, so seed once
  and take them back to back, changing only `-appTheme`.

The seeds are marketing fixtures, not test fixtures: `-seedSeattleDemo`, `-seedBudgetDemo`,
`-seedQueryDemo`, and `-seedHindiDemo` exist so the captures look like notes somebody wrote rather
than a feature list being exercised. `-seedStructuredDemo`, `-seedTableDemo` and `-seedCodeDemo` stay
as they are — the UI tests launch them, and `-seedCodeDemo` is a parser fixture that reads like one,
which is why the marketing code card has its own seed.

Seed and open are **separate launches**, and so is a theme change: the theme is read once at launch,
and reusing a session that was started dark has produced a "light" capture in dark. Terminate between
every shot, and look at what came out.

### Known gaps

- **The Share sheet has no capture, and cannot have one from a simulator.** `-openShare` presents the
  real sheet, but a simulator has no Messages, Mail, or AirDrop, so the sheet it draws offers
  Reminders and Save to Files — which would read as a claim that those are the only places a note can
  go. The Share section on `/` is deliberately copy-only until this is captured **on a device**, and
  its copy names no destinations for the same reason: a note goes to "whichever apps and services are
  already available on your iPhone", not to a fixed list of four.
- There is no **blank-editor** capture. `structure-light` is a note that already has structure in it.
- The recording **level meter is flat** in every capture, for the reason above.
- `home-dark`, `recording-light`, `search-light`, `calendar-light` and `lock-light` are current and
  unused. The Light/Dark pair is the editor; `/voice` shows the Quick Voice paused panel rather than
  the in-note one; and the homepage dropped its timeline and lock devices when it went from fourteen
  screenshots to nine, then its consent and retry devices at seven. All are kept because they are
  captured, correct, and one section change away from being wanted.

## Regenerating the social card

`public/og.png` is rendered from `scripts/og.html`, so it can be rebuilt whenever the home-screen
capture changes rather than being a mystery binary:

```sh
cd public && python3 -m http.server 3200 &
npm run og -- http://localhost:3200
```

**Point it at a plain static server, not `next start`.** The script copies the template into `public/`
for the length of the render, and `next start` builds its static-file manifest at boot — so a file
added afterwards 404s and the card comes out as a screenshot of the **404 page**. It looks plausible
until you open it. A server rooted at `public/` has everything the template asks for: the icon, and
the current `home-light` capture.

It uses the production app icon (`public/android-chrome-512x512.png`, which is
`Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` resized) and the current
`home-light` capture. Nothing in it is redrawn.

## Before shipping a change

- **Check the browser console on every page**, not just that it renders. A hydration mismatch
  logs an error and nothing else — it shipped unnoticed on all six pages once, from an inline
  script mutating `<html>` before React hydrated.
- **Clear `.next/cache/images` after replacing a screenshot.** The optimizer keys its cache on the
  request URL, and every capture keeps its filename — so a rebuild happily serves the *old* image
  and the page looks untouched. This wasted a review round: the page showed a three-day-old
  timeline beside a fresh one and nothing was wrong with the code.
- **Keep Next.js on a patched release.** Vercel refuses to *deploy* a build made with a version
  carrying a security advisory — the build itself succeeds, all routes prerender, and then the
  deployment is marked ERROR with "Vulnerable version of Next.js detected". `15.5.4` was blocked
  this way; the `backport` dist-tag (`npm view next dist-tags`) is the patched 15.5.x line and is
  a drop-in. `npm audit` still reports `postcss` and `sharp` through Next, and their only fix is
  Next 16 — a major upgrade, not a deploy fix, and not what Vercel blocks on.
- **Never run `next build` while `next dev` is running.** They share `.next/`, and the build
  pulls it out from under the dev server, which then 500s with `Cannot find module './611.js'`.
- **Look at the screenshots, at full size, not in a downscaled contact sheet.** Run
  `node scripts/audit-shots.mjs` (below) — it fails if any device is masked, clipped by an
  `overflow` ancestor, or geometrically intersecting another device. Then open a few of the
  cropped PNGs it writes and check the app UI is all there.
- No page may scroll horizontally. `node scripts/audit-widths.mjs` walks every route at
  320 / 360 / 390 / 430 / 768 / 1024 / 1280 / 1440 / 1728 px and names what sticks out.
- `npm run build` must prerender every route as static (`○`), and `npm run typecheck` must pass.
  `npm run lint` is **not** wired up — there is no ESLint config in this project, and `next lint`
  is deprecated besides, so the script drops into an interactive setup prompt. Don't put it in CI
  until someone decides which linter this project wants.
- Every screenshot needs descriptive alt text; only the brand mark and the CTA feather use
  `alt=""`.
- Adding a route means adding it to `app/sitemap.ts`.
