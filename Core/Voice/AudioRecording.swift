import Foundation

/// Abstraction over audio recording so the voice state machine stays testable.
/// See docs/05-architecture.md §13, §19 (temp audio security).
@MainActor
protocol AudioRecording: AnyObject {
    /// Request mic permission if undetermined. Returns whether recording is allowed.
    func requestPermission() async -> Bool
    /// Begin recording to a protected temporary file; returns its URL.
    func start() throws -> URL
    /// Stop recording; returns the finalized file URL (nil if nothing was recorded).
    func stop() -> URL?
    /// Discard the current recording and delete the temporary file.
    func cancel()
    /// Delete a temporary recording file (after success / discard).
    func cleanup(_ url: URL)
    /// Normalized input level 0...1 for the waveform.
    var level: Float { get }
    /// Called when the system takes the microphone away mid-recording (incoming call, Siri).
    /// The recording has already stopped by then; the captured audio is still on disk.
    var onInterruption: (() -> Void)? { get set }
}
