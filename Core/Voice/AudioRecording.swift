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
    /// Close the recorder and hand back the **finalized** file, or `nil` if nothing was recorded.
    ///
    /// Asynchronous because finalization is: the encoder has to confirm it has written the container
    /// out before anybody may read it. `VoiceCaptureModel.Phase.finishing` is the state this call
    /// happens in, and the invariant it now actually enforces is that **no upload begins until the
    /// recorder has confirmed it stopped and the resulting file has been measured**. Reading a
    /// container mid-flush is how an app uploads five seconds of a thirty-second thought.
    ///
    /// Measuring here rather than at the call site is what keeps that invariant in one place: a
    /// caller cannot forget to check, because an unmeasurable recording arrives already saying so
    /// (`FinishedRecording.isTranscribable`).
    func finish() async -> FinishedRecording?
    /// Discard the current recording and delete the temporary file.
    func cancel()
    /// Delete a temporary recording file (after success / discard).
    func cleanup(_ url: URL)
    /// Normalized input level 0...1 for the waveform.
    var level: Float { get }
    /// Whether the microphone is actually open right now, asked of the recorder itself rather than
    /// of anything that remembers what it was told.
    ///
    /// The capture's `phase` is what the app believes; this is what is true. They diverged silently
    /// before an encoder failure had any way to be noticed, and a live waveform drawn over a dead
    /// input is the exact shape of that divergence.
    var isCapturing: Bool { get }
    /// Called when the capture stops without the app asking it to — the microphone taken away by a
    /// call, Siri, or an audio route the recorder cannot continue on (`AudioRouteChange`), and
    /// **also** the recorder failing on its own.
    ///
    /// One callback, but no longer one meaning: `RecordingStop` says which happened. An interruption
    /// ends the capture and keeps the audio, exactly as before (`docs/10-voice-v2.md` §14). An
    /// `unexpected` stop keeps the audio too — dropping it would be the one outcome worse than a
    /// rejected upload — but it MUST NOT be presented as a completed recording, because the user was
    /// still speaking into a microphone that had already closed.
    ///
    /// The recording has stopped by the time this is called; nothing here ever reopens it.
    var onCaptureEnded: ((RecordingStop) -> Void)? { get set }
}
