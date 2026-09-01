import Foundation

/// The one place the app reads the wall clock for anything a reader *sees* — which day is today,
/// which month the calendar opens on, how notes bucket into periods.
///
/// In a release build this is `Date()` and nothing else. In a Debug build it can be pinned from the
/// command line (`-pinnedNow 2026-08-31T09:41:00`), so a screenshot session started at 00:02 on the
/// first of the month can still show the library as it stood the evening before — and so a test that
/// seeds "yesterday" and asserts "Yesterday" can read the same clock twice instead of racing midnight.
///
/// Storage timestamps (`createdAt`, `updatedAt`, `deletedAt`) deliberately do **not** go through
/// here: what a note records about when it was written is a fact, not a way of looking at it.
enum AppClock {
    static var now: Date {
        #if DEBUG
        if let pinned = DebugLaunch.pinnedNow { return pinned }
        #endif
        return Date()
    }
}
