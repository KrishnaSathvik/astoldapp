import Testing
import Foundation
@testable import Yourly

/// What VoiceOver is told as a capture changes state (`docs/10-voice-v2.md` §6).
///
/// The spec names the transitions out loud: *Recording started · Paused · Recording resumed ·
/// Transcribing · Transcript added*. Pause and resume make this a release-blocking gap rather than a
/// nicety — a paused recorder and a running one differ by a word and a glyph, and a reader who cannot
/// see either has no way to know which one they are in (`RULES.md` §4).
///
/// One definition, both presentations. The panel and Quick Voice are the same capture in two skins,
/// and two lists of spoken strings would drift the first time one of them was edited.
@MainActor
struct VoiceAnnouncementTests {

    private typealias Phase = VoiceCaptureModel.Phase

    @Test func theCaptureSaysWhenItStarts() {
        #expect(Phase.announcement(from: .requestingPermission, to: .recording) == "Recording started")
        #expect(Phase.announcement(from: .idle, to: .recording) == "Recording started")
    }

    @Test func pausingAndResumingAreBothAnnounced() {
        #expect(Phase.announcement(from: .recording, to: .paused) == "Paused")
        #expect(Phase.announcement(from: .paused, to: .recording) == "Recording resumed")
    }

    /// Resuming MUST NOT be announced as starting. They are different facts: one says a recording
    /// exists, the other says the one you already made is running again.
    @Test func resumingIsNotAnnouncedAsStarting() {
        #expect(Phase.announcement(from: .paused, to: .recording) != "Recording started")
    }

    @Test func theUploadAndItsResultAreAnnounced() {
        #expect(Phase.announcement(from: .finishing, to: .transcribing) == "Transcribing")
        #expect(Phase.announcement(from: .needsConsent, to: .transcribing) == "Transcribing")
        #expect(Phase.announcement(from: .transcribing, to: .idle) == "Transcript added")
    }

    /// Phase 2B, `docs/10-voice-v2.md` §13: a failure that **kept** the recording says so out loud.
    ///
    /// This is the one thing a reader cannot get any other way. "Couldn't transcribe" alone reads as
    /// *your words are gone*, and somebody who cannot see the screen has no other signal that four
    /// minutes of speech survived the error.
    @Test func aFailureThatKeptTheRecordingSaysSo() {
        let said = Phase.announcement(from: .transcribing, to: .failed(.offline))
        #expect(said?.contains(VoiceErrorCopy.retainedNotice) == true)
    }

    /// And a failure that kept nothing promises nothing. The audio for these is already deleted, so
    /// claiming it is still on the iPhone would be worse than saying nothing at all.
    @Test func aFailureWithNothingKeptIsNotAnnounced() {
        #expect(Phase.announcement(from: .transcribing, to: .failed(.noSpeech)) == nil)
        #expect(Phase.announcement(from: .transcribing,
                                   to: .failed(.monthlyLimitReached(resetsAt: nil))) == nil)
        #expect(Phase.announcement(from: .transcribing,
                                   to: .failed(.recordingTooLong(maxSeconds: 300))) == nil)
    }

    /// **Delete Recording** removes something the user was told still existed, so its removal is
    /// stated too.
    @Test func deletingTheRecordingIsAnnounced() {
        #expect(Phase.announcement(from: .failed(.offline), to: .idle) == "Recording deleted")
    }

    /// Silence everywhere else. §6's discipline is "nothing repeated, nothing on every second" — a
    /// capture that narrates every internal step is one a screen-reader user cannot listen past.
    @Test func nothingElseIsAnnounced() {
        #expect(Phase.announcement(from: .idle, to: .requestingPermission) == nil)
        #expect(Phase.announcement(from: .recording, to: .finishing) == nil)
        #expect(Phase.announcement(from: .finishing, to: .needsConsent) == nil)
        #expect(Phase.announcement(from: .recording, to: .recording) == nil)
        #expect(Phase.announcement(from: .paused, to: .paused) == nil)
        // Cancelling is not a transcript.
        #expect(Phase.announcement(from: .recording, to: .idle) == nil)
        #expect(Phase.announcement(from: .paused, to: .idle) == nil)
        // Still on screen, still not repeated for its own sake: the failure's *copy* is not the
        // announcement — the durability of the recording is (see above).
        #expect(Phase.announcement(from: .failed(.offline), to: .failed(.offline)) == nil)
        #expect(Phase.announcement(from: .requestingPermission, to: .permissionDenied) == nil)
    }
}
