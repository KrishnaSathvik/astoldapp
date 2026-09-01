#!/bin/bash
# The canonical raw library (2026-09-01): untouched, native-resolution simulator raws of ONE demo
# dataset, numbered as the raw-library table in docs/appstore/README.md numbers them.
#
#   xcodebuild build -scheme Yourly -configuration Debug \
#     -destination 'platform=iOS Simulator,id=<device>' -derivedDataPath <isolated path>
#   xcrun simctl install <device> <path>/Yourly.app     # DEBUG build: the flags are #if DEBUG
#   bash docs/appstore/capture-library.sh
#
# Raw means raw: no frame, no crop, no headline. Composition happens later, from a chosen crop.
# 13 (the real Share sheet) is captured on a device by hand — a simulator offers Reminders and
# Save to Files, and a frame implying those are the destinations is worse than no frame.
#
# Seed and open are SEPARATE launches (a single launch that resets and opens can race the store it
# just wiped), and nothing else may touch this simulator while it runs.
set -u

DEV=${DEV:-9099927E-D0E0-4822-A3A1-89E7AF19B109}   # iPhone 17 Pro Max — 1320 × 2868, captured 1:1
BUNDLE=com.astold.app
OUT=${OUT:-/Users/krishnasathvikmantripragada/Yourly/docs/appstore/raw/library}
# The whole session is seen at 09:41 on August 31, 2026, whatever the Mac's clock says: the status
# bar is overridden below, and the app's own clock is pinned to agree with it (`AppClock`).
NOW=${NOW:-2026-08-31T09:41:00}
BASE_NOCONSENT="-hasCompletedWelcome YES -pinnedNow $NOW"
BASE="$BASE_NOCONSENT -voiceTranscriptionConsent YES"

mkdir -p "$OUT"

# ONLY="03-quickvoice-listening 09-calendar" retakes just those (seeding still runs — it is cheap,
# and a shot must never depend on whatever the store happened to hold).
shot() {
  local name="$1"; local theme="$2"; local wait="$3"; shift 3
  if [ -n "${ONLY:-}" ] && [ "$name" != _seed ] && [[ " $ONLY " != *" $name "* ]]; then return; fi
  xcrun simctl terminate "$DEV" "$BUNDLE" >/dev/null 2>&1 || true
  # Pairs first, bare flags after: NSUserDefaults parses -key value pairs, and a bare flag
  # interleaved with them swallows the next value.
  xcrun simctl launch "$DEV" "$BUNDLE" ${SHOT_BASE:-$BASE} -appTheme "$theme" "$@" >/dev/null 2>&1
  sleep "$wait"
  xcrun simctl io "$DEV" screenshot "$OUT/$name.png" >/dev/null 2>&1
  printf '%-30s %s\n' "$name" "$(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" 2>/dev/null | tail -2 | tr -d '\n' | tr -s ' ')"
}

# Wipe the store and seed it; the next `shot` then opens a launch that only reads.
seed() { shot _seed light 4 -resetStore "$@"; }

xcrun simctl status_bar "$DEV" override --time "9:41" \
  --batteryState discharging --batteryLevel 100 \
  --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4

# 01–02  Home: the whole library as Home draws it, Light and Dark.
seed -seedLibraryHome
shot 01-home-light                 light 7
shot 02-home-dark                  dark  7

# 03–04  Quick Voice, listening then paused. The timer is the recorder's real elapsed time, so the
#        wait *is* the number on the clock; `-voiceDemoLevels` gives the silent simulator a voice.
shot 03-quickvoice-listening       light 20 -openQuickVoice -voiceDemoLevels
shot 04-quickvoice-paused          light 27 -voicePauseAfter 23 -openQuickVoice -voiceAutoPause -voiceDemoLevels

# 05  What that recording becomes: a titleless, three-paragraph note.
seed -seedLibraryNote voice
shot 05-voice-note-titleless       light 6 -openSeededNote

# 06 / 07 / 12  The structured note — clean, with the keyboard and toolbar, and in Dark.
seed -seedLibraryNote "Japan Trip"
shot 06-japan-trip-light           light 6 -openSeededNote
shot 07-japan-trip-keyboard-up     light 8 -openSeededNote -caretAtStart
shot 12-japan-trip-dark            dark  6 -openSeededNote

# 08  The circular checklist, unmistakably.
seed -seedLibraryNote "Launch Checklist"
shot 08-launch-checklist           light 6 -openSeededNote

# 09  Calendar: the same library spread over the month, today selected with four notes.
seed -seedLibraryCalendar
shot 09-calendar                   light 7 -openCalendar

# 10  A pasted table with words around it.
seed -seedLibraryNote "Trip Budget"
shot 10-trip-budget                light 6 -openSeededNote

# 11  Code that still looks like code: language label, Copy Code, prose either side.
seed -seedLibraryNote "Monthly Units Query"
shot 11-monthly-units-query        light 6 -openSeededNote

# 15 / 14  An ordinary note, and the retained recording over it. The recovery panel sits on a
#          plain note on purpose: on a diagram it reads as an edge case, on a weekend it reads as
#          what it is.
seed -seedLibraryNote "Weekend Plan"
shot 15-weekend-plan               light 6 -openSeededNote
shot 14-voice-recovery             light 8 -openSeededNote -autoStartVoice -voiceFakeFailure

# 16  Website only: the consent sheet the first finished recording raises. Consent is the one
#     flag every other shot pre-grants, so this launch drops it.
SHOT_BASE="$BASE_NOCONSENT" shot 16-voice-consent light 7 -openSeededNote -autoStartVoice

rm -f "$OUT/_seed.png"
