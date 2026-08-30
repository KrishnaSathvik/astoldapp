import Foundation

/// Abstraction over audio recording so the voice state machine stays testable.
/// See docs/05-architecture.md §13, §19 (temp audio security).
@MainActor
protocol AudioRecording: AnyObject {
    /// Request mic permission if undetermined. Returns whether recording is allowed.
    func requestPermission() async -> Bool
    /// Begin recording to a protected temporary file; returns its URL.
    func start() throws -> URL
    /// Hold the microphone without closing the file. The recording so far is kept, and `resume()`
    /// continues **the same file** — `docs/10-voice-v2.md` §5 requires one continuous container,
    /// because the relay measures the container it is given and that measurement is the authority.
    func pause()
    /// Continue the paused recording into the file `start()` opened.
    func resume()
    /// Stop recording; returns the finalized file URL (nil if nothing was recorded).
    func stop() -> URL?
    /// Discard the current recording and delete the temporary file.
    func cancel()
    /// Delete a temporary recording file (after success / discard).
    func cleanup(_ url: URL)
    /// Normalized input level 0...1 for the waveform.
    var level: Float { get }
    /// Called when the microphone is taken away mid-recording, whatever took it: an incoming call,
    /// Siri, or an audio route the recorder cannot safely continue on — AirPods removed, a headset
    /// unplugged, no input left at all (`AudioRouteChange`).
    ///
    /// One callback for all of them on purpose. They differ in what happened and not in what must
    /// happen next: the capture ends, and the audio already on disk goes on to transcription rather
    /// than being thrown away (`docs/10-voice-v2.md` §14). The recording has stopped by the time this
    /// is called; nothing here ever reopens it.
    var onInterruption: (() -> Void)? { get set }
}
