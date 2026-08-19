# As Told website — v8

Static marketing site for **As Told**. Deployed on Vercel (`cleanUrls: true`, so pages are
linked without the `.html` suffix).

## Pages
`index.html` · `voice-notes.html` · `private-notes.html` · `multilingual.html` ·
`privacy.html` · `support.html` — plus `styles.css` and `site.js`.

## Two rules for this site

1. **Light theme only.** The site does not follow `prefers-color-scheme`; there is a single
   palette in `:root`, taken from the app's own light tokens (`docs/03-design-system.md` §15) so
   the site and the product read as one thing. The app's *dark mode* still appears on the page —
   as a screenshot in the Appearance section — because that is product content, not site chrome.

2. **Every screenshot is the real app, at its current capability.** No mockups, no illustrated
   UI, and no screenshot older than the feature it illustrates. As Told does structured writing
   (headings, bullets, numbered lists, checklists) and spoken structure commands — a screenshot
   of a bare paragraph makes the app look like an earlier version of itself. The `og.png` social
   card is composed around a real capture too.

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

Seeding runs in a `.task` on the root view, so seed and open are **separate launches** — passing
`-resetStore -seed… -openSeededNote` together races and can capture the previous note.

Then downscale to 720 px wide and save as WebP into `assets/shots/`. Filenames the pages expect:

| File | Launch arguments | Section |
|---|---|---|
| `home-light` / `home-dark` | `-resetStore -seedSampleNotes` | hero, Appearance |
| `editor-light` | `-resetStore -seedStructuredDemo` then `-openSeededNote` | Write, Structure |
| `recording-light` | …then `-openSeededNote -autoStartVoice` | Speak |
| `consent-light` | same, once consent has not been given | Privacy |
| `voice-light` | `-resetStore -seedVoiceDemo` then `-openSeededNote` | Verbatim, Languages, Voice notes |
| `search-light` | `-searchQuery Seward` | Timeline, search & calendar |
| `calendar-light` | `-openCalendar` | Timeline, search & calendar |
| `lock-light` | `-forceLocked` | Private notes |

Two of these are timing-sensitive:

- **`recording-light`** — the recording panel lives for about a second before the consent
  sheet covers it. Take a burst of frames ~0.35 s apart and keep the one with the waveform.
- **`consent-light`** — only appears while `voiceTranscriptionConsent` is unset, so capture it
  on a simulator whose app data has been erased, or before granting.

Grant the microphone first (`xcrun simctl privacy $SIM grant microphone com.astold.app`),
otherwise the system permission alert sits on top of every shot. If one has already been
queued, `xcrun simctl erase` is the reliable way to clear it.

## Other assets

`apple-touch-icon.png`, `favicon.ico`, `favicon-16/32`, `android-chrome-*`, `site.webmanifest`,
`og.png`. `favicon.svg` and `logo.png` are no longer referenced — the traced SVG was 1.6 MB, and
the `.ico` plus PNG icons already cover every browser.

## Linking rule

**Every internal reference is relative, and page links carry `.html`.**
`href="support.html"`, `src="assets/shots/home-light.webp"` — never `href="/support"` or
`src="/assets/…"`.

Root-relative paths resolve against the filesystem root when a page is opened from disk, so
`/assets/mark-160.webp` becomes `file:///assets/mark-160.webp` and the logo silently disappears.
Extensionless links exist only because Vercel's `cleanUrls` invents them, so they 404 on every
other server and when double-clicking a file. Relative `.html` links work in all three places:
opened from disk, on any plain static server, and on Vercel — where `cleanUrls` 308-redirects
`/support.html` to `/support`, so the clean URL is still the one that gets indexed.

Only these stay absolute, because the spec requires it: `<link rel="canonical">`, `og:url`,
`og:image`, `twitter:image`, and the URLs in `sitemap.xml`.

To check a change, open `index.html` from disk and click every footer link.

## Before shipping a change

- No page may scroll horizontally at 320 / 360 / 390 / 768 / 1440 px.
- The App Store CTA is the `.btn.is-pending` "Coming to the App Store" state until there is a
  real store URL to link to. Swap it for an `<a class="btn" href="…">` at launch.
- Bump the `?v=` on `styles.css` / `site.js` when either changes.
