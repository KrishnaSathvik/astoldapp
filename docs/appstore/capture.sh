#!/bin/bash
# Recapture the App Store raws into raw/, then run compose.py to rebuild 6.9/.
#
#   xcrun simctl boot "iPhone 17 Pro Max"        # 1320x2868 native — captured 1:1, no resampling
#   xcodebuild build -scheme Yourly -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
#   xcrun simctl install <device> <path>/Yourly.app    # must be a DEBUG build: the flags are #if DEBUG
#   bash docs/appstore/capture.sh
#   python3 docs/appstore/compose.py
#
# The per-shot wait matters. 14-voice-dark is grabbed at 2s because the simulator has no microphone
# input: the recording starts, fails a few seconds later, and the panel switches to "Couldn't
# transcribe that recording." Waiting longer silently captures that error state instead of the live
# recorder — it looks plausible at a glance and is the wrong frame to ship.
set -u
DEV=${DEV:-9099927E-D0E0-4822-A3A1-89E7AF19B109}   # iPhone 17 Pro Max
BUNDLE=com.astold.app
OUT=/Users/krishnasathvikmantripragada/Yourly/docs/appstore/raw
BASE="-hasCompletedWelcome YES -voiceTranscriptionConsent YES"

shot() {
  local name="$1"; local theme="$2"; local wait="$3"; shift 3
  xcrun simctl terminate "$DEV" "$BUNDLE" >/dev/null 2>&1
  # Pairs first, bare flags after, -searchQuery last: NSUserDefaults parses -key value pairs and a
  # bare flag interleaved with them swallows the next value (docs/appstore/README.md).
  xcrun simctl launch "$DEV" "$BUNDLE" $BASE -appTheme "$theme" "$@" >/dev/null 2>&1
  sleep "$wait"
  xcrun simctl io "$DEV" screenshot "$OUT/$name.png" >/dev/null 2>&1
  printf '%-22s %s\n' "$name" "$(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" 2>/dev/null | tail -2 | tr -d '\n' | tr -s ' ')"
}

shot 01-hero            light 7 -resetStore -seedSampleNotes
shot 10-editor-toolbar  light 7 -resetStore -seedSeattleDemo -openSeededNote -caretAtEnd
shot 02-structure       light 7 -resetStore -seedSeattleDemo -openSeededNote
shot 13-seattle-dark    dark  7 -resetStore -seedSeattleDemo -openSeededNote
shot 05-paste           light 7 -resetStore -seedBudgetDemo -openSeededNote
shot 04-multilingual    light 7 -resetStore -seedVoiceDemo -openSeededNote
shot 12-calendar        light 7 -resetStore -seedSampleNotes -openCalendar
shot 06-lock            light 7 -resetStore -seedSampleNotes -forceLocked
shot 11-search          light 8 -resetStore -seedSampleNotes -searchQuery Alaska
# Voice: grab a couple of seconds in, while the level meter is live.
shot 14-voice-dark      dark  2 -resetStore -seedSeattleDemo -openSeededNote -autoStartVoice
