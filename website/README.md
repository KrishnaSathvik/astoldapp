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
| `/` | The product story: hero → write → structure → paste → voice → multilingual → timeline & privacy → light/dark → CTA |
| `/voice` | How voice capture works, end to end |
| `/languages` | Telugu, Hindi, English and the mix — a tabbed example switcher, then fidelity |
| `/privacy` | The privacy document |
| `/support` | FAQ, grouped: writing, paste, voice, privacy & storage, recovery |
| `/terms` | The terms document |

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
   of a system badge; the SVG is gone. The listing is live, so `APP_STORE_URL` is set and every
   CTA is a real link — only Apple's own supplied badge asset may replace the text.

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

Only three components ship JavaScript: `SiteHeader` (the mobile menu), `RevealObserver`
(the fade-in), and `LanguageSwitcher` (the `/languages` example tabs). Everything else is a
server component.

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
- **Device sizes** are `sm` 268px / `md` 300px / `lg` 356px / `xl` 404px, set as `--device-w`.
  At `lg` a 1206×2622 capture renders 774px tall; that is what a section beside it has to
  accommodate. `PhoneShot` declares the intrinsic size once — update it there if the capture
  device ever changes.
- **`PhonePair stagger`** steps the second device *down* (72px), never sideways.
- **`PhoneFigure` needs its size class on the `<figure>` too** — a flex item with no width
  collapses to nothing until its image loads.
- **Never lock `body` overflow.** `<html>` is the scroll port here; hiding body's overflow makes
  body a scroll container and the sticky header stops sticking.
- **The App Store CTA** links to the live listing. `APP_STORE_URL` in `lib/site.ts` is the only
  place the store is named — it flips every CTA on the site at once, and `APP_STORE_ID` beside it
  feeds the iOS Safari smart banner (`itunes.appId` in `app/layout.tsx`). Setting the constant
  back to `null` restores the `pending` "Coming to the App Store" state; that branch is kept for
  exactly that reason.
- **The language specimens carry no linguistic gloss.** "English nouns taking Telugu case
  endings" is true, academic, and worth nothing to a reader who already speaks that way. Show
  the sentence; let them recognise themselves. Captions say what the *product* does.
- **`LanguageSwitcher` renders every panel into the DOM** and hides the inactive ones with the
  `hidden` attribute — those Telugu and Hindi sentences are what the page ranks for, so they
  must not sit behind a click. A `<noscript>` block reveals all five and drops the tab bar.
  Never toggle its panels with an inline `style={{display}}`: that outranks the media query
  that makes the open panel a two-column grid.

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
| `home-light` | `-resetStore -seedSampleNotes` | `/` hero, `/` Light/Dark, `og.png` |
| `home-dark` | same store, `-appTheme dark` | `/` Light/Dark |
| `structure-light` | `-resetStore -seedSeattleDemo` then `-openSeededNote` | `/` Write |
| `toolbar-light` | same, `-openSeededNote -caretAtEnd` | `/` Structure |
| `table-light` | `-resetStore -seedBudgetDemo` then `-openSeededNote` | `/` Paste |
| `recording-light` | `-voiceTranscriptionConsent YES -openSeededNote -autoStartVoice` | `/` Voice, `/voice` hero |
| `consent-light` | `-openSeededNote -autoStartVoice`, consent **not** granted | `/voice` |
| `voice-light` | `-resetStore -seedVoiceDemo` then `-openSeededNote` | `/` Multilingual, `/voice`, `/languages` |
| `hindi-light` | `-resetStore -seedHindiDemo` then `-openSeededNote` | `/` Multilingual |
| `search-light` | `-searchQuery Seward` | `/` Timeline |
| `calendar-light` | `-openCalendar` | `/` Timeline |
| `lock-light` | `-forceLocked` | `/` Privacy |

Three of these need care:

- **`recording-light`** — with consent ungranted the panel lives well under a second before the
  consent sheet covers it, which is why this one passes `-voiceTranscriptionConsent YES`. The level
  meter reads flat because a simulator in a quiet room has no input; that is the app telling the
  truth, and the alt text says "level meter" rather than claiming a live waveform.
- **`consent-light`** — the opposite: it only appears while `voiceTranscriptionConsent` is unset, so
  capture it before granting, or after `xcrun simctl erase`.
- **`home-light` / `home-dark`** — the Light/Dark pair must be the *same* store at the *same* scroll
  position, so take them back to back without `-resetStore` in between. The sample timeline is dated
  relative to now, so a pair taken on different days will not match.

The seeds are marketing fixtures, not test fixtures: `-seedSeattleDemo`, `-seedBudgetDemo`, and
`-seedHindiDemo` exist so the captures look like notes somebody wrote rather than a feature list
being exercised. `-seedStructuredDemo` and `-seedTableDemo` stay as they are — `TablePresentationUITests`
launches the latter.

### Known gaps

- There is no **blank-editor** capture. `structure-light` is a note that already has structure in it.
- There is no **dark editor** capture. Light/Dark uses the two home-screen shots.
- The recording **level meter is flat** in every capture, for the reason above.

## Regenerating the social card

`public/og.png` is rendered from `scripts/og.html`, so it can be rebuilt whenever the home-screen
capture changes rather than being a mystery binary:

```sh
npm run build && npx next start -p 3100 &
npm run og -- http://localhost:3100
```

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
