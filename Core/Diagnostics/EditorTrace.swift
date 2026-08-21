import Foundation
import UIKit
import os

/// A stopwatch for the cold path into the editor — debug builds only, and only when the app is
/// launched with `-traceEditor`.
///
/// "The first note feels frozen" is not a measurement, and neither is a stopwatch held against a
/// screen recording. This prints one timeline per editor opening, in milliseconds from the tap, so the
/// several seconds can be attributed to the step that actually spends them rather than to whichever
/// step is easiest to blame. Every mark is also an `os_signpost` Point of Interest, so the same run
/// shows up on an Instruments track beside the Time Profiler's main-thread samples.
///
/// Step names only — never a character of the note (RULES.md §3).
enum EditorTrace {

    #if DEBUG
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-traceEditor")
    private static let signposter = OSSignposter(subsystem: "com.astold.app", category: .pointsOfInterest)
    @MainActor private static var opened: DispatchTime?
    @MainActor private static var last: DispatchTime?
    #endif

    /// The tap. Restarts the clock, because each opening is its own story — the first is the one that
    /// hurts, and it has to be legible next to the second.
    @MainActor static func open(_ label: String) {
        #if DEBUG
        guard isEnabled else { return }
        opened = .now()
        last = nil
        print("\neditor-trace ── \(label)")
        mark("tap")
        observeKeyboard()
        #endif
    }

    /// The keyboard is a different process, and its first appearance after a launch is the step most
    /// often mistaken for "the editor is slow". One observer per opening, removed when it fires.
    @MainActor private static func observeKeyboard() {
        #if DEBUG
        var token: (any NSObjectProtocol)?
        token = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardDidShowNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { mark("keyboard on screen") }
            if let token { NotificationCenter.default.removeObserver(token) }
        }
        #endif
    }

    @MainActor static func mark(_ label: @autoclosure () -> String) {
        #if DEBUG
        guard isEnabled, let opened else { return }
        let now = DispatchTime.now()
        let total = Double(now.uptimeNanoseconds - opened.uptimeNanoseconds) / 1_000_000
        let delta = last.map { Double(now.uptimeNanoseconds - $0.uptimeNanoseconds) / 1_000_000 }
        last = now
        let name = label()
        // A step that costs more than a frame is the only kind worth looking at twice.
        let flag = (delta ?? 0) >= 16.7 ? "  ←" : ""
        print(String(format: "editor-trace %8.1f ms  (+%6.1f)  %@%@",
                     total, delta ?? 0, name, flag))
        signposter.emitEvent("editor", "\(name, privacy: .public)")
        #endif
    }

    /// Wraps one step so its own cost is measured rather than inferred from the gap to the next mark.
    @MainActor static func measure<T>(_ label: String, _ work: () -> T) -> T {
        #if DEBUG
        guard isEnabled else { return work() }
        let started = DispatchTime.now()
        let result = work()
        let ms = Double(DispatchTime.now().uptimeNanoseconds - started.uptimeNanoseconds) / 1_000_000
        mark(String(format: "%@ [%.1f ms]", label, ms))
        return result
        #else
        return work()
        #endif
    }
}
