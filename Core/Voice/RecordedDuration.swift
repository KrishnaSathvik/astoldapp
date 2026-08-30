import Foundation

/// How much audio a capture has actually recorded, across any number of pauses.
///
/// **The timer measures recorded audio, never wall-clock time** (`docs/10-voice-v2.md` §5). A capture
/// that counted the pause would reach the five-minute cap without five minutes of speech in it, and the
/// user would be cut off mid-thought by a limit they had not spent. So the count is a sum of the
/// segments the microphone was actually open for:
///
///     record 2:30  →  pause 5:00  →  record 2:30   =  5:00 of voice
///
/// Kept out of `VoiceCaptureModel` deliberately. `docs/10-voice-v2.md` §4 requires every transition to
/// be checkable without a microphone, a network, or a view; arithmetic over instants is the half of
/// that which needs no seams at all, and it is the half that decides whether somebody gets cut off.
///
/// Instants come from the caller rather than from a clock read inside — that is what lets a test span
/// an hour of pause without waiting for one.
struct RecordedDuration: Equatable {
    /// Audio from segments that have already ended.
    private var banked: Duration = .zero
    /// When the segment in flight began, or `nil` when the microphone is not open.
    private var segmentStart: ContinuousClock.Instant?

    /// Whether audio is being captured right now — the state, not a flag beside one. §4 names
    /// `recording` plus an `isPaused` boolean as exactly how a paused recorder keeps counting time.
    var isRunning: Bool { segmentStart != nil }

    /// Begins a fresh capture, discarding anything counted before it.
    mutating func start(at now: ContinuousClock.Instant) {
        banked = .zero
        segmentStart = now
    }

    /// Banks the segment in flight. A second pause is a no-op rather than a second banking of the
    /// same audio.
    mutating func pause(at now: ContinuousClock.Instant) {
        guard let segmentStart else { return }
        banked += Self.segment(from: segmentStart, to: now)
        self.segmentStart = nil
    }

    /// Opens a new segment. Resuming something already running would restart the segment and lose the
    /// audio counted so far, so it is a no-op.
    mutating func resume(at now: ContinuousClock.Instant) {
        guard segmentStart == nil else { return }
        segmentStart = now
    }

    /// The audio recorded so far, including the segment in flight.
    func elapsed(at now: ContinuousClock.Instant) -> Duration {
        guard let segmentStart else { return banked }
        return banked + Self.segment(from: segmentStart, to: now)
    }

    /// How much of `cap` is left to speak into. Never negative — a cap already spent offers nothing.
    func remaining(of cap: Duration, at now: ContinuousClock.Instant) -> Duration {
        max(.zero, cap - elapsed(at: now))
    }

    /// Whether the capture has spoken its way to `cap`.
    func hasReached(_ cap: Duration, at now: ContinuousClock.Instant) -> Bool {
        elapsed(at: now) >= cap
    }

    /// A segment's length, floored at zero. `ContinuousClock` does not run backwards, but this type
    /// must not be the thing that assumes it: a negative segment would hand the cap more room than the
    /// user has actually spoken.
    private static func segment(from start: ContinuousClock.Instant,
                                to now: ContinuousClock.Instant) -> Duration {
        max(.zero, start.duration(to: now))
    }
}
