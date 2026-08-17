# Product Requirements Document — Premium Notes App

## 1. Product summary

`[AppName]` is a premium, minimal iPhone notes application for capturing thoughts by typing or speaking.

It is built around a deliberately narrow loop:

> **Open → write or speak → leave.**

The app organizes notes automatically by date, stores them locally, and avoids accounts and productivity mechanics. Voice capture should preserve the user's natural speech, including English, Telugu, Hindi, and code-switching between those languages.

### Tagline

**Write it. Say it. Keep it.**

### Product category

Private thought capture / minimal notes.

### Positioning

Not "AI notes."

Not "a second brain."

Not "a journal that tells you what to write."

Not "Apple Notes with more buttons."

The intended feeling is:

> A quiet personal place where a thought can be put down without having to organize, rewrite, categorize, or explain it.

---

## 2. Problem

Traditional note apps are powerful, but their power often becomes interface:

- folders
- formatting
- attachments
- tables
- collaboration
- checklists
- scanning
- templates
- toolbars
- sharing
- account/sync setup

Voice-first products often go in the opposite direction and add:

- AI summaries
- meeting workflows
- action items
- assistants
- retrieval chat
- integrations
- accounts

There is room for a product whose value is **restraint**:

- open instantly
- type immediately
- speak naturally
- preserve the thought
- find it later

---

## 3. Target user

### Primary user

Someone who frequently has thoughts they want to preserve but does not want to maintain an organizational system.

Examples:

- a personal thought
- an idea
- something to remember
- a reflection
- a rough plan
- a line or phrase
- something easier to say than type
- mixed Telugu/English or Hindi/English speech

### User mindset

The user should not need to decide:

- what folder this belongs in
- what tag to use
- whether this is a "voice note" or "text note"
- whether to save
- whether to format
- whether AI should improve it

---

## 4. Jobs to be done

### JTBD 1 — Capture

When I have a thought, I want to put it somewhere immediately so I do not lose it.

### JTBD 2 — Speak instead of type

When typing feels slow or inconvenient, I want to speak naturally and have the words inserted into my note.

### JTBD 3 — Preserve my voice

When I speak in Telugu, Hindi, English, or mix them, I want the transcript to preserve how I spoke rather than translate or professionally rewrite me.

### JTBD 4 — Find it later

When I remember a word, topic, or approximate date, I want to locate the note without having organized it in advance.

### JTBD 5 — Keep it private

When I write personal material, I want the app to avoid unnecessary accounts, cloud storage, analytics content capture, and exposed previews.

---

## 5. Product principles

### 5.1 Immediate

The shortest path to a note should be one tap from Home.

### 5.2 Quiet

The interface must not ask for attention unnecessarily.

### 5.3 Faithful

Voice transcription is a capture tool, not an editor.

### 5.4 Private

Notes are local-first. The server never stores the note database.

### 5.5 Forgiving

Autosave, undo, and safe error recovery should make the product difficult to lose work in.

### 5.6 Native

Use native iOS conventions wherever they improve familiarity, accessibility, motion, or system integration.

---

## 6. V1 scope

### Included

- first-run welcome
- chronological Home
- automatic day grouping
- create note
- optional title
- plain text body
- autosave
- edit note
- delete note
- Undo delete
- full-text search
- calendar date navigation
- voice recording
- post-recording transcription
- English/Telugu/Hindi target
- mixed-language target
- optional Face ID/device lock
- privacy cover in app switcher when locked
- system-controlled Light/Dark appearance
- accessibility support
- error/retry states for transcription

### Explicitly excluded from V1

- accounts
- Sign in with Apple
- folders
- tags
- pinning
- favorites
- rich text
- Markdown UI
- images
- attachments
- scanning
- handwriting
- checklists
- collaboration
- share extension
- widgets
- watchOS app
- reminders
- notifications
- journaling prompts
- mood tracking
- streaks
- AI summaries
- AI rewriting
- AI chat
- semantic search
- cloud note storage
- iCloud sync
- export
- audio archive
- manual theme selector

---

## 7. Core user flows

### 7.1 First launch

1. Native launch screen appears.
2. Welcome screen appears.
3. User sees product name, tagline, short explanation, Continue.
4. No permissions are requested.
5. User taps Continue.
6. Home opens.
7. Welcome never appears again unless app data is reset.

### 7.2 Create by typing

1. User taps `+`.
2. Editor opens immediately.
3. Date is shown automatically.
4. Title is available but optional.
5. Body is focused and ready for input.
6. User types.
7. Note autosaves.
8. User navigates back.
9. Note appears at the top of Today's group.
10. If title and body are both empty, the draft is discarded.

### 7.3 Create by voice

1. User opens a new or existing note.
2. User places cursor where transcript should be inserted.
3. User taps microphone.
4. Microphone permission is requested only if not already determined.
5. Recording interface appears inline/bottom.
6. User speaks.
7. User taps Done.
8. Recording stops.
9. App shows `Transcribing…`.
10. Audio is securely sent to the transcription service.
11. Transcript is returned.
12. Transcript is inserted at the saved cursor position.
13. Transcript becomes ordinary editable text.
14. Temporary audio is deleted.
15. Note autosaves.

### 7.4 Browse

1. Home shows all notes, newest first.
2. Notes are grouped by calendar day.
3. Older notes appear through continuous scrolling.
4. Loading older batches is invisible.

### 7.5 Search

1. User invokes native Home search.
2. User types a query.
3. Search matches title and body.
4. Results show a short preview and date.
5. Selecting a result opens the note.

### 7.6 Calendar

1. User taps Calendar.
2. Month sheet appears.
3. Days containing one or more notes show a subtle dot.
4. User taps a date.
5. Home navigates/filters to that date.
6. User can return to Today.

### 7.7 Delete

1. User swipes a note left.
2. Delete action is revealed.
3. Deleting removes the note from Home immediately.
4. Undo appears for a short period.
5. Undo restores the note.

### 7.8 Lock

1. User enables Lock with Face ID in Settings.
2. System authentication is requested in context.
3. When app leaves active state, sensitive content is covered.
4. On return, app authenticates before restoring content.
5. Device passcode fallback is allowed when appropriate.

---

## 8. Home requirements

### Header

Show:

- current date, subtle
- `Today`, prominent
- Calendar action

Do not show:

- greeting
- weather
- current time
- quote
- writing prompt
- streak
- statistics

### Note row

If title exists:

- title: one line where possible
- body preview: up to 2–3 lines

If title does not exist:

- body becomes the primary preview
- never generate `Untitled`

Do not show time on normal Home rows.

### Grouping

Examples:

- Today
- Yesterday
- August 15
- August 14

Home is the "all notes" experience. There is no separate All Notes screen.

### Performance

The experience is continuous, but implementation may fetch notes in batches.

Initial target:

- fetch latest ~40 notes
- fetch older notes as scrolling approaches the end
- never expose page numbers or Load More

Exact batch size is an implementation tuning parameter.

---

## 9. Editor requirements

### Required visual elements

- Back
- overflow menu
- date
- optional title field
- body text area
- microphone control

### Forbidden default UI

- Save button
- formatting bar
- checklist button
- attachment row
- AI button
- word count
- prominent timestamp
- toolbar occupying writing width

### Autosave

Autosave must:

- debounce active typing
- flush on navigation away
- flush on app background
- never require user confirmation

Target debounce: 300–600 ms.

### Empty drafts

If:

- normalized title is empty
- body is empty/whitespace
- no transcription is pending

then navigating away should remove the draft.

---

## 10. Voice requirements

See `04-voice-transcription.md`.

Critical rule:

> The system must not intentionally translate, summarize, rewrite, polish, or grammar-correct the user's speech.

V1 target languages:

- English
- Telugu
- Hindi
- Telugu + English
- Hindi + English

Accuracy must be evaluated against real recordings before release.

---

## 11. Privacy requirements

### Local note ownership

The note database lives in the app container on device.

### Server boundary

The transcription service receives only what it requires for transcription.

V1 backend must not:

- store notes
- keep audio after request completion
- persist transcript content
- log transcript text
- log raw audio
- run AI summarization
- use note contents as analytics

### Note context

Do not send the full existing note to the transcription model just to improve transcription.

Use:

- recorded audio
- static transcription instructions
- allowed language hints
- carefully chosen non-user-content metadata

### App switcher

When app lock is enabled, note content should not remain readable in the iOS app-switcher snapshot.

### Analytics

Prefer Apple platform diagnostics/product metrics for V1.

If custom analytics are added later:

- never include note text
- never include transcript text
- never include audio
- never include search queries

---

## 12. Appearance requirements

- Follow system appearance automatically.
- No Light/Dark selector in V1.
- All semantic colors have Light and Dark values.
- Support Dynamic Type.
- Support VoiceOver.
- Respect Reduce Motion.
- Do not communicate state by color alone.
- Keep controls at accessible hit sizes.

See `03-design-system.md`.

---

## 13. Non-functional requirements

### Launch

Perceived launch should be immediate.

### Offline

Typing, editing, browsing, search, calendar, and deletion work offline.

Voice recording works offline, but transcription requires network in V1.

If network is unavailable after recording:

- do not lose the recording immediately
- show a clear Retry/Discard state
- do not silently upload later without user intent

### Reliability

No user text should disappear because of:

- navigation
- app background
- interrupted transcription
- temporary network failure

### Security

- no OpenAI secret in application binary
- HTTPS only
- production transcription endpoint protected against obvious abuse
- App Attest is recommended for production requests

---

## 14. Success criteria for V1

### Product

A new user can:

- install
- enter Home
- create a note
- type
- leave
- reopen
- find the note

without learning an organizational model.

### Voice

For benchmark recordings:

- language/script is preserved
- code switching is retained
- transcript does not translate into English
- transcript does not intentionally rewrite grammar
- names/place accuracy is measured separately
- failure states are explicit rather than hallucinated

### UX

- no visible Save action
- no permanent toolbar
- no account wall
- Home remains useful with hundreds/thousands of notes
- Dark Mode feels intentionally designed, not inverted

### Engineering

- local data survives app restarts
- delete Undo works
- app lock works across background/foreground
- API key is server-side
- temporary audio cleanup is verified
- accessibility audit passes before release

---

## 15. Release gate

V1 is not ready for App Store submission until all of the following are true:

- typing flow is stable
- note persistence is stable
- empty draft cleanup is stable
- search is useful at realistic note counts
- calendar navigation works across months/timezones
- Face ID/device authentication behavior is tested
- app-switcher privacy cover is tested
- microphone permission denial/recovery is tested
- transcription error and offline flows are tested
- English benchmark passes
- Telugu benchmark passes
- Hindi benchmark passes
- Telugu-English code-switch benchmark passes
- Hindi-English code-switch benchmark passes
- no transcript/audio content appears in server logs
- Light/Dark/Dynamic Type/VoiceOver are reviewed
