# Tech Stack

## 1. Recommended V1 stack

### iOS

| Concern | Choice |
|---|---|
| Language | Swift 6+ |
| UI | SwiftUI |
| Minimum target | iOS 26+ recommended for this premium latest-iOS product |
| Persistence | SwiftData |
| Concurrency | Swift Concurrency (`async/await`, actors) |
| Observation | `@Observable` / SwiftUI state |
| Biometrics | LocalAuthentication |
| Audio recording | AVFoundation |
| Networking | URLSession |
| App integrity | DeviceCheck / App Attest |
| Settings | `@AppStorage` / UserDefaults |
| Logging | OSLog |
| Performance diagnostics | MetricKit |
| Icons | SF Symbols |
| Localization infrastructure | String Catalogs (`.xcstrings`) |
| Testing | Swift Testing + XCTest/XCUITest where required |

### Transcription backend

| Concern | Choice |
|---|---|
| Runtime | Node.js 24 LTS |
| Language | TypeScript |
| Framework | Fastify |
| Validation | Zod or JSON-schema/Fastify schema |
| OpenAI | Official OpenAI Node SDK |
| Model | `gpt-4o-transcribe` |
| Rate limit | Redis-backed in production if needed |
| Integrity | App Attest verification |
| Deployment | small container/service |
| Persistence | none for note/audio content |
| Logs | structured metadata-only logs |

---

# 2. Why native SwiftUI

This app depends heavily on the qualities iOS already does well:

- typography
- text editing
- accessibility
- safe-area behavior
- keyboard integration
- sheets
- swipe actions
- search
- haptics
- biometric UI
- system appearance
- SF Symbols
- modern materials

A cross-platform UI layer would add complexity without helping the V1 goal.

---

# 3. Why iOS 26+ as the recommended starting target

This is a new, premium iPhone-first product intended to use current Apple visual behavior and modern SwiftUI.

Benefits:

- smaller compatibility surface
- modern system materials/components
- current SwiftUI APIs
- easier design consistency
- fewer fallback implementations

If market reach later requires an older minimum, reevaluate before implementation is too deep.

Do not silently lower the target and then recreate modern controls manually.

---

# 4. Why SwiftData

The app needs:

- local persistence
- simple model
- SwiftUI integration
- queries
- no external database dependency
- schema evolution path

SwiftData is an appropriate first choice.

The `NoteStore` boundary keeps search/persistence swappable if a real performance issue appears later.

---

# 5. Why not Realm/Firebase/Supabase for V1

They solve problems this product does not currently have.

V1 has:

- no account
- no cross-device custom sync
- no collaboration
- no server note database

Adding a cloud database would weaken the simplicity/privacy story and increase operational work.

---

# 6. Search choice

Start:

- local lexical search
- SwiftData-backed

Benchmark before optimizing.

If 10k-note search is not good enough:

- add an internal SQLite FTS5/GRDB implementation behind `NoteStore`

Do not add Algolia/Elasticsearch/vector search for a local personal notes V1.

---

# 7. Audio choice

Use AVFoundation.

Recommended shape:

- `AVAudioSession`
- `AVAudioRecorder` or `AVAudioEngine`
- temporary `.m4a`
- level metering for waveform/voice visualization

Choose `AVAudioRecorder` first unless audio-pipeline requirements make `AVAudioEngine` necessary.

It is simpler for a bounded recording workflow.

---

# 8. Transcription model

## Recommended

**`gpt-4o-transcribe`** — the flagship file-transcription model, verified end-to-end (spoken clip →
relay → accurate verbatim transcript). The relay default is `gpt-4o-transcribe` (see
`transcription-service/`).

Other file-transcription models on the account (benchmark before switching, Phase 11):
`gpt-transcribe` (sibling, similar quality), `gpt-4o-mini-transcribe` (faster/cheaper, slightly lower
accuracy), `whisper-1` (returns detected language via `verbose_json`, but weaker on low-resource
languages / code-switching), `gpt-4o-transcribe-diarize` (speaker labels — not needed here).

Useful capabilities for this product include:

- original-language transcription
- expected-language context
- transcription prompting/context (our static verbatim prompt)
- json/text response formats (no per-language detection field for the gpt-4o family)

### Why not Realtime first

The product intentionally shows final text after the user taps Done.

Realtime adds:

- session lifecycle
- WebRTC/mobile transport work
- partial transcript state
- more edge cases

without creating V1 user value.

Evaluate `gpt-live-transcribe` (available on the account, alongside the `gpt-realtime-*` family) only
if the design later wants live text while the user is still talking.

---

# 9. Backend choice

## Node.js 24 LTS + TypeScript + Fastify

Reasons:

- production LTS runtime
- simple multipart endpoint
- official OpenAI SDK support
- easy request validation
- straightforward container deployment
- good testing ecosystem

The service should remain intentionally small.

### Routes

Minimum:

```text
GET  /health
POST /v1/app-attest/challenge
POST /v1/app-attest/register
POST /v1/transcriptions
```

Exact App Attest flow may adjust these routes.

---

# 10. Why not call OpenAI directly with a normal key from iOS

A normal secret embedded in an iOS binary can be extracted.

Therefore:

- standard API credential stays server-side
- iPhone calls your controlled endpoint

This is non-negotiable for production.

---

# 11. App Attest

Use Apple's DeviceCheck/App Attest service to make the transcription service more confident that requests originate from a legitimate app instance.

It is anti-abuse protection, not user authentication.

This is particularly important because the product intentionally has no account.

---

# 12. Face ID

Framework:

`LocalAuthentication`

Use system authentication UI.

Prefer a device-owner authentication policy that uses biometrics and allows appropriate system passcode fallback rather than attempting to build a custom PIN security system.

Required plist privacy text should be clear and specific.

Example intent:

`Use Face ID to keep your notes private when you reopen the app.`

Final copy should be reviewed before submission.

---

# 13. Light / Dark

Implementation:

- system appearance
- adaptive Asset Catalog colors
- native semantic colors
- no manual setting

Do not force `.preferredColorScheme`.

---

# 14. Design-system implementation

Recommended namespace:

```swift
enum DS {
    enum Spacing { ... }
    enum Radius { ... }
    enum Motion { ... }
}
```

Colors:

```swift
extension Color {
    static let appCanvas = Color("Canvas")
    static let appAccent = Color("Accent")
}
```

Typography should lean on native styles and Dynamic Type rather than fixed font structs everywhere.

---

# 15. Networking

Use URLSession and Codable.

No Alamofire required.

Requirements:

- request timeout
- cancellation
- upload progress/state if needed
- correlation/request ID
- typed error mapping

Do not leak provider error messages directly to UI.

---

# 16. Dependencies policy

### Prefer zero/very few iOS dependencies.

Before adding a package, ask:

1. Does Apple provide this?
2. Is the dependency solving a proven V1 problem?
3. Does it add privacy/security surface?
4. Can the app survive if the package is abandoned?

Likely V1 iOS third-party dependencies:

**none**, unless search performance later justifies GRDB.

Backend dependencies are normal and isolated.

---

# 17. CI/CD

Recommended:

### iOS

- GitHub
- Xcode Cloud or GitHub Actions + macOS runner
- TestFlight
- SwiftFormat/SwiftLint only if they improve consistency without fighting Xcode

### Backend

- GitHub Actions
- typecheck
- unit/integration tests
- container build
- deploy staging → production

Environment separation:

- local
- staging
- production

OpenAI keys are environment secrets.

---

# 18. Configuration

Do not hardcode:

- API base URL
- max recording duration
- request timeout
- model name
- rate limits

Use environment/build configuration.

However, do not make fundamental product behavior remotely mutable in unsafe ways.

For example, a remote config should not be able to turn "verbatim capture" into AI rewriting.

---

# 19. Privacy/diagnostics stack

Preferred:

- App Store Connect analytics
- MetricKit
- OSLog

Avoid third-party session replay in V1.

Never install a replay SDK capable of observing typed note content.

---

# 20. Official references

Apple SwiftData:
https://developer.apple.com/documentation/swiftdata

Apple LocalAuthentication:
https://developer.apple.com/documentation/localauthentication

Apple App Attest / validating apps:
https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server

OpenAI file transcription:
https://developers.openai.com/api/docs/guides/speech-to-text

OpenAI Realtime overview:
https://developers.openai.com/api/docs/guides/realtime

Node.js release status:
https://nodejs.org/en/about/previous-releases
