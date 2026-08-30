#!/bin/bash
# Recapture the App Store raws into raw/, then run compose.py to rebuild 6.9/.
#
#   xcrun simctl boot "iPhone 17 Pro Max"        # 1320x2868 native — captured 1:1, no resampling
#   xcodebuild build -scheme Yourly -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
#   xcrun simctl install <device> <path>/Yourly.app    # must be a DEBUG build: the flags are #if DEBUG
#   bash docs/appstore/capture.sh
#   python3 docs/appstore/compose.py
#
# Seed and open are SEPARATE launches: seeding runs before the first render, but a single launch that
# both resets and opens can still race the store it just wiped. Terminate between every shot.
#
# Nothing else may touch this simulator while this runs — not a UI test, not a website capture. A
# concurrent `simctl launch` reseeds the store underneath a shot and you get a screenshot of somebody
# else's note (2026-08-28; see the "fifth contention source" note in the session memory).
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

# --- Timeline / Home ---------------------------------------------------------
shot 01-hero            light 7 -resetStore -seedSampleNotes
shot 11-search          light 8 -resetStore -seedSampleNotes -searchQuery Alaska
shot 12-calendar        light 7 -resetStore -seedSampleNotes -openCalendar
shot 06-lock            light 7 -resetStore -seedSampleNotes -forceLocked

# --- Quick Voice, the V2 entry point -----------------------------------------
# `-openQuickVoice` presents Home's capture on launch; neither state finishes on a timer, so the
# screenshot is never racing an auto-Done.
shot 20-quickvoice      light 7 -openQuickVoice
shot 21-quickvoice-dark dark  7 -openQuickVoice

# --- The structured note, light and dark -------------------------------------
shot _seed              light 6 -resetStore -seedSeattleDemo
shot 02-structure       light 6 -openSeededNote
shot 13-seattle-dark    dark  6 -openSeededNote
shot 10-editor-toolbar  light 7 -openSeededNote -caretAtEnd
# In-note voice: `-voiceAutoPause` holds the panel open over a real note. Without it `-autoStartVoice`
# finishes after 1.5s and the capture lands on a failed transcription instead of the recorder.
shot 22-voice-paused    light 7 -openSeededNote -autoStartVoice -voiceAutoPause
# The retained-recording state, driven by the stand-in transcription that always fails.
shot 23-retry           light 7 -openSeededNote -autoStartVoice -voiceFakeFailure

# --- Paste / table -----------------------------------------------------------
shot _seed              light 6 -resetStore -seedBudgetDemo
shot 05-paste           light 6 -openSeededNote

# --- Code --------------------------------------------------------------------
shot _seed              light 6 -resetStore -seedQueryDemo
shot 24-code            light 6 -openSeededNote
shot 25-code-dark       dark  6 -openSeededNote

# --- Multilingual ------------------------------------------------------------
shot _seed              light 6 -resetStore -seedVoiceDemo
shot 04-multilingual    light 6 -openSeededNote
shot _seed              light 6 -resetStore -seedHindiDemo
shot 26-hindi           light 6 -openSeededNote

rm -f "$OUT/_seed.png"

# =============================================================================
# The raw library (added 2026-08-29)
#
# Thirteen shots whose job is to be *believable*, not to be composed as-is: rich, ordinary notes a
# person could plausibly have written, so a frame can be chosen later rather than captured to order.
# Numbered from 30 so nothing here collides with the raws the shipped frames are built from.
#
# Not capturable here: the native Share sheet (`38-share-sheet`). `-openShare` presents the real
# sheet, but a simulator has no Messages, Mail, WhatsApp or AirDrop — it offers Reminders and Save to
# Files, and a frame implying those are the destinations is worse than no frame. Device only.
# =============================================================================

# --- 1. Home, a library somebody has been using -------------------------------
shot 30-home-library    light 7 -resetStore -seedShowcaseNotes

# --- 2 / 11. Quick Voice, listening and paused --------------------------------
# The timer is the recorder's own elapsed time, so the wait *is* the number on the clock. 00:01 reads
# as staged; the shot waits for a mid-sentence number instead. `-voiceDemoLevels` moves the waveform:
# a simulator has no audio input, so the real microphone reports the floor and the waveform draws
# flat — see the flag's note in DebugSupport.swift.
shot 31-quickvoice-listening light 16 -openQuickVoice -voiceDemoLevels
shot 40-quickvoice-paused    light 22 -voicePauseAfter 18 -openQuickVoice -voiceAutoPause -voiceDemoLevels

# --- 3. A spoken note that moves between languages ----------------------------
shot _seed              light 6 -resetStore -seedWeekendThoughtsDemo
shot 32-voice-multilingual light 6 -openSeededNote

# --- 4 / 12. Every structure in one note, and the in-note recorder over it -----
shot _seed              light 6 -resetStore -seedAlaskaDemo
shot 33-structure-alaska light 7 -openSeededNote
shot 41-note-voice      light 14 -openSeededNote -autoStartVoice -voiceHold -voiceDemoLevels

# --- 5 / 10. Code with prose on both sides, light and dark --------------------
shot _seed              light 6 -resetStore -seedSQLDemo
shot 34-code-sql        light 6 -openSeededNote
shot 39-code-sql-dark   dark  6 -openSeededNote

# --- 6. A table worth reading, with words and a link around it ----------------
shot _seed              light 6 -resetStore -seedJapanDemo
shot 35-table-japan     light 6 -openSeededNote

# --- 7. Pasted structure that is visibly not code -----------------------------
shot _seed              light 6 -resetStore -seedArchitectureDemo
shot 36-paste-architecture light 6 -openSeededNote

# --- 13. An ordinary note. No code, no table, no gimmick ----------------------
shot _seed              light 6 -resetStore -seedSundayDemo
shot 42-writing-sunday  light 6 -openSeededNote

# --- 8. The retained recording, driven by the real failure --------------------
# Over the ordinary note on purpose. A recovery panel sitting on an architecture diagram reads as a
# developer's edge case; sitting on somebody's Sunday it reads as the thing it is.
shot 37-voice-recovery  light 8 -openSeededNote -autoStartVoice -voiceFakeFailure

rm -f "$OUT/_seed.png"
