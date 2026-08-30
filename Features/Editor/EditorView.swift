import SwiftUI
import SwiftData

/// Plain-text editor: date, optional title, body. No Save button; the writing controls live in one
/// floating toolbar above the keyboard rather than in the header (`WritingToolbar`, RULES.md §1, §7).
///
/// Two intentions, one screen (product behavior matrix):
///  - **New note** — opens ready to capture: the body takes focus and the keyboard rises.
///  - **Existing note** — opens for *reading*: nothing becomes first responder, no keyboard.
///    Tapping the title or the body starts editing exactly where the user tapped.
struct EditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeStore.self) private var themeStore
    /// The app's *effective* rendered scheme, already accounting for `AppRootView`'s
    /// `preferredColorScheme`. Used to resolve the keyboard's appearance under "Use device settings",
    /// so the keyboard is never asked to work its own out. See `AppTheme.keyboardAppearance(inheriting:)`.
    @Environment(\.colorScheme) private var colorScheme
    let note: Note
    /// Set by Home to nil the navigationDestination item — the reliable way to pop an item-based push.
    var onClose: (() -> Void)? = nil
    /// Which screen pushed this one, so Back can name where it actually goes (`EditorOrigin`).
    /// Defaults to Home, so every caller that does not say otherwise reads exactly as it always has.
    var origin: EditorOrigin = .notes
    @State private var model: EditorModel?
    @State private var voice: VoiceCaptureModel?
    @State private var bodySelection = NSRange(location: 0, length: 0)
    @State private var bodyFocused = false
    /// Two-way title focus. Plain `@State`, not `@FocusState`: the title field is UIKit now that
    /// it scrolls with the body (`NotePageView`), so focus crosses the same binding the body's does.
    @State private var titleFocused = false
    @State private var capturedInsertOffset = 0
    /// Whether the body had the caret when recording started — decides whether the keyboard comes
    /// back after the transcript lands.
    @State private var refocusBodyAfterVoice = false
    /// Owns the one-time voice tip. A reference type so the decision (and its persistence) is testable
    /// away from the view — see `WritingEducation`.
    @State private var education = WritingEducation()
    @State private var showsWritingHelp = false
    /// The table the reader is open on. A tap while *reading* the note puts one here; editing the
    /// note's text is unaffected, because the tap that opens this never fires while writing.
    @State private var openedTable: TableBlock?
    /// The way the Style menu reaches the body text view — see `BodyEditorActions`.
    @State private var bodyActions = BodyEditorActions()
    /// The note as it stood when Share was tapped. Non-nil presents the system sheet.
    ///
    /// A snapshot, deliberately: everything the sheet sends is decided at the moment of the tap, so a
    /// note cannot change underneath an open sheet and nothing the sheet does can reach back into the
    /// note (`NoteSharePayload`).
    @State private var sharing: NoteSharePayload?

    private var isCapturing: Bool { voice != nil }
    /// True while the user is actually editing (a field owns the keyboard), false while reading.
    private var isEditing: Bool { bodyFocused || titleFocused }

    /// The note's own line in the navigation bar: when it was last written to, in the reader's locale.
    ///
    /// `updatedAt` rather than `createdAt` (2026-08-26). What a reader wants from a timestamp on the
    /// note they are looking at is when it last changed; the note's birthday is the timeline's job, and
    /// the timeline already does it. Formatted through `Date.FormatStyle` rather than a hand-written
    /// pattern, so "August 24, 2026 at 10:16" is the *English* spelling of it and every other locale
    /// gets its own — a hard-coded `MMMM d, yyyy` is only correct where the calendar happens to agree.
    ///
    /// Minute precision, so this changes at most once a minute while somebody is typing.
    private var dateText: String {
        note.updatedAt.formatted(date: .long, time: .shortened)
    }

    /// What Share would send right now, or `nil` when the note is empty.
    ///
    /// Read from the **model**, which is what the body binding writes on every keystroke, so this
    /// tracks the note as it is being typed and Share enables itself the moment there is a first
    /// character. The payload actually shared is rebuilt at the tap, after pending edits commit.
    private func currentPayload(_ model: EditorModel) -> NoteSharePayload? {
        NoteSharePayload.make(title: model.title, body: model.body)
    }

    /// Commit what is on screen, put the keyboard away, then open the sheet.
    ///
    /// The order is the whole point. A table cell being edited lives in the card's own field until it
    /// commits, so someone who changes `Anchorage` to `Fairbanks` and taps Share straight away would
    /// otherwise send `Anchorage` — the note on screen and the note in `body` disagreeing for exactly
    /// as long as that field is open. `commitPendingEdits()` closes it and hands back the text view's
    /// own text, which is authoritative.
    ///
    /// Sharing never *changes* a note. Committing a cell is the writer's own edit landing through the
    /// ordinary undoable path — it would have landed on the next tap anywhere else.
    private func share(_ model: EditorModel) {
        commitPendingBodyEdits(model)
        // The title is tidied on the same terms it is tidied on any other way out of the field, so a
        // title of nothing but spaces does not become a line of nothing but spaces in somebody's inbox.
        model.endTitleEditing()
        bodyFocused = false
        titleFocused = false
        sharing = currentPayload(model)
    }

    /// Folds an edit that is still living *outside* `body` back into the note.
    ///
    /// Today that means one thing: a table cell being edited lives in the card's own field until it
    /// commits. Anything that reads or persists the note has to call this first, or it works from a
    /// `body` the writer can see is out of date on screen.
    ///
    /// This used to exist only inside `share(_:)`, which made Share the one exit in the app that did
    /// not lose an open cell edit — tapping Back dropped it, because `finish()` flushed a `body` the
    /// cell had never reached (fixed 2026-08-27). It is the same generic flush now, called from every
    /// exit, rather than a favour Share does for itself.
    @discardableResult
    private func commitPendingBodyEdits(_ model: EditorModel) -> Bool {
        guard let committed = bodyActions.commitPendingEdits(), committed != model.body else {
            return false
        }
        model.body = committed
        return true
    }

    private func close() {
        // The capture is finalized **here**, at the tap, rather than left to `onDisappear`.
        //
        // Order is the whole reason: leaving mid-upload retains the recording and remembers it
        // (`VoiceCaptureModel.finishOnLeave`), and Home looks for a recording to offer back the moment
        // this route clears. Finalizing on teardown instead put the two the wrong way round — Home
        // asked before anything had been remembered, and a recording that was perfectly safe on disk
        // was not offered until the next launch.
        //
        // `onDisappear` still calls it, for the ways out that do not come through this button. The
        // second call is a no-op: the recording is already retained by then.
        voice?.finishOnLeave()
        // onDisappear runs finish() (flush or discard empty draft).
        if let onClose { onClose() } else { dismiss() }
    }


    var body: some View {
        ZStack {
            Color.ds.canvas.ignoresSafeArea()
            if let model {
                editor(model)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if model == nil {
                model = EditorModel(note: note, context: context)
                // A note created by the compose button is still an empty draft here — that, and only
                // that, means "the user came to write", so only that opens the keyboard.
                if note.isEmptyDraft { bodyFocused = true }
            }
            #if DEBUG
            if DebugLaunch.caretAtEnd {
                bodySelection = NSRange(location: (note.body as NSString).length, length: 0)
                bodyFocused = true
            }
            if DebugLaunch.autoStartVoice, let model {
                startVoice(model)
                // `-voiceAutoPause` holds the panel open instead of finishing it, which is the only
                // way to capture the in-note recorder: a screenshot cannot outrun a 1.5s auto-Done.
                // `-voiceHold` does the same for the *recording* state, which otherwise finishes
                // before the timer ever reaches a number that does not look staged.
                if DebugLaunch.voiceAutoPause {
                    Task {
                        try? await Task.sleep(for: .seconds(DebugLaunch.voicePauseAfter))
                        voice?.pause()
                    }
                } else if !DebugLaunch.voiceHold {
                    Task { try? await Task.sleep(for: .seconds(1.5)); voice?.done() }
                }
            }
            // Screenshot hook only: the system sheet is iOS's own view and appears on a tap. This
            // goes through the same `share(_:)` the button calls, so the payload is the real one.
            if DebugLaunch.openShare, let model {
                Task { try? await Task.sleep(for: .seconds(1)); share(model) }
            }
            #endif
        }
        .onDisappear {
            // Back is not a cancel — for a half-typed table cell exactly as much as for a running
            // recording (RULES.md §4). The open cell is folded back into `body` *before* `finish()`
            // flushes, because `finish()` writes whatever `body` holds and would otherwise persist a
            // note missing the words somebody had just typed into a cell.
            if let model { commitPendingBodyEdits(model) }
            // A running recording is finished and transcribed, exactly as
            // backgrounding, a phone call, and the duration cap already do — leaving used to delete
            // the audio, so tapping Back mid-sentence destroyed everything the user had said.
            // `finishOnLeave` stops the microphone either way, so nothing is left hot or on disk.
            voice?.finishOnLeave()
            voice = nil
            model?.finish()
        }
        .onChange(of: scenePhase) { _, phase in
            // Same order as leaving: commit the open cell, then flush. A note written while the app is
            // going away must be the note that was on screen.
            if phase != .active, let model {
                commitPendingBodyEdits(model)
                model.flush()
            }
            // Recording cannot continue once the app is suspended, so finish the capture with the
            // audio already on disk rather than stranding it — from `paused` as much as from
            // `recording`, because a paused capture is holding words that were already spoken
            // (`docs/10-voice-v2.md` §14). Nothing else backgrounding does is destructive: a
            // transcription in flight is left alone, and a retained recording stays retained.
            if phase == .background { voice?.finishOnBackground() }
        }
        // Back left, the note's date centred, Share right — and deliberately no overflow menu. An
        // overflow in the editor is how duplicate / word count / pin arrive, and those are all still on
        // the do-not-build list (RULES.md §4, §7). Share is one button because it is one verb.
        //
        // `.principal` rather than a `Spacer`-balanced `HStack`: the date is centred on the **screen**,
        // not in whatever room Back and Share leave over, so it does not drift as Back's word changes
        // between "Notes", "Search", and "Calendar" (`EditorOrigin`).
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { close() } label: {
                    // The chevron alone, from every origin (2026-08-26). The mark is a complete back
                    // button on this platform, and the word beside it was the header describing the
                    // room the reader is leaving rather than the note in front of them. Nothing is
                    // lost that a screen reader needs: `backAccessibilityLabel` still names the
                    // destination, and it still differs by origin (RULES.md §4).
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.ds.accent)
                }
                .accessibilityLabel(origin.backAccessibilityLabel)
            }
            ToolbarItem(placement: .principal) {
                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(Color.ds.textTertiary)
                    .lineLimit(1)
                    .accessibilityLabel("Last edited \(dateText)")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { if let model { share(model) } } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.ds.accent)
                }
                // Visible but disabled on an empty note, rather than absent: a control that appears and
                // disappears as the first character is typed is the header moving while somebody writes.
                .disabled(model.flatMap(currentPayload) == nil)
                .accessibilityLabel("Share note")
                .accessibilityIdentifier("Share")
            }
        }
        .sheet(item: $sharing) { payload in
            NoteShareSheet(payload: payload) { sharing = nil }
        }
        .sheet(isPresented: $showsWritingHelp) { WritingHelpSheet() }
        .fullScreenCover(item: $openedTable) { table in
            TableReaderView(table: table) { openedTable = nil }
        }
    }

    /// The whole note is one page and it scrolls as one: date, title, and body live inside a single
    /// scroll view (`NotePageView`). They used to be stacked here, with only the body scrolling, so a
    /// long note ran on underneath a date and title pinned to the top of the screen and was clipped
    /// mid-line against them. The placeholder went in with them for the same reason — it belongs at
    /// the first line of the body, and only the page knows where that is.
    ///
    /// One line, and nothing else, under an empty note. The marker cheat-sheet that used to live
    /// there went with the arrival of the Style menu: teaching syntax before the first word is asking
    /// a writer to learn something in order to start writing (RULES.md §7).
    @ViewBuilder private func editor(_ model: EditorModel) -> some View {
        BodyTextView(
            text: Binding(get: { model.body }, set: { model.body = $0 }),
            selectedRange: $bodySelection,
            isFocused: $bodyFocused,
            isEditable: !isCapturing,   // recording/transcription owns the anchor
            keyboardAppearance: themeStore.theme.keyboardAppearance(inheriting: colorScheme),
            actions: bodyActions,
            title: Binding(get: { model.title }, set: { model.title = $0 }),
            titleFocused: $titleFocused,
            openTable: { openedTable = $0 },
            titleEditingEnded: { model.endTitleEditing() },
            bodyPlaceholder: "Start writing…"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // `safeAreaInset`, not `overlay`. The bar has to *take* the room it occupies, not float over
        // it: as an overlay the text view still believed it owned the whole screen down to the
        // keyboard, so UIKit lifted the line being typed to a "visible" position that was in fact
        // behind the bar, and a long note was written into a strip the writer could not see. The
        // height comes from the bar itself — measured by SwiftUI, never a constant — so it stays right
        // at every Dynamic Type size, in the recording state, and with the keyboard up or down.
        .safeAreaInset(edge: .bottom, spacing: 0) { writingLayer(model) }
        .padding(.horizontal, DSSpacing.screenH)
        .padding(.top, DSSpacing.s4)
        .animation(DSMotion.fast, value: isEditing)
    }

    /// Everything a writer does to the note, in one place, directly above the keyboard: its structure
    /// and its voice (RULES.md §1 and §7, amended 2026-08-20). The navigation bar keeps what belongs to
    /// navigation and to the note's identity — Back, and above the body, the date and title — so the
    /// top of the screen reads as the page rather than as a control panel.
    ///
    /// While recording, the bar *is* the recording panel: the same island, in its other state. Voice is
    /// not a mode the editor enters, it is the other way to write, and it should not look like a
    /// different screen arriving.
    @ViewBuilder private func writingLayer(_ model: EditorModel) -> some View {
        if let voice {
            RecordingPanel(model: voice) { endVoice() }
                .padding(.vertical, DSSpacing.s4)
        } else if WritingToolbar.Mode.resolve(bodyFocused: bodyFocused,
                                              titleFocused: titleFocused,
                                              inCode: caretIsInCode(model)) != .hidden
                    || education.showsVoiceStructureTip {
            // Nothing shown means nothing reserved: while the *title* has the keyboard there is no bar,
            // and the body below it must not be inset for a bar that is not there.
            VStack(spacing: DSSpacing.s3) {
                // Sits above the toolbar that produced the transcript, after the capture UI has gone —
                // never stacked on the consent sheet, because it is only reachable once a
                // transcription has actually succeeded.
                if education.showsVoiceStructureTip {
                    VoiceStructureTip { education.dismissVoiceStructureTip() }
                }
                WritingToolbar(
                    mode: .resolve(bodyFocused: bodyFocused, titleFocused: titleFocused,
                                   inCode: caretIsInCode(model)),
                    current: BlockStyle.current(in: model.body, selection: bodySelection),
                    appendsToEnd: !bodyFocused,
                    onStyle: { bodyActions.apply($0) },
                    onWritingHelp: { showsWritingHelp = true },
                    onVoice: { startVoice(model) }
                )
            }
            .padding(.top, DSSpacing.s4)
            .padding(.bottom, DSSpacing.s4)
            .animation(DSMotion.fast, value: education.showsVoiceStructureTip)
            .animation(DSMotion.fast, value: bodyFocused)
            .animation(DSMotion.fast, value: titleFocused)
        }
    }

    /// Whether the caret is inside a code fence, where structure does not apply.
    ///
    /// Read from the document rather than tracked as state: the fence that encloses the caret can open
    /// or close from an edit anywhere in the note — a paste, an undo, a transcript landing — and a flag
    /// would go stale the moment it did.
    private func caretIsInCode(_ model: EditorModel) -> Bool {
        guard model.body.contains(CodeBlock.fence) else { return false }
        return MarkupDocument(model.body).isLiteral(atSource: bodySelection.location)
    }

    private func startVoice(_ model: EditorModel) {
        // Where the transcript will land is decided *now*, before recording, and the recording owns
        // that anchor (docs/04-voice-transcription.md §8):
        //  - caret in the body  → insert at the caret
        //  - reading, no caret  → append to the end of the note
        refocusBodyAfterVoice = bodyFocused
        capturedInsertOffset = bodyFocused
            ? bodySelection.location
            : (model.body as NSString).length

        var service = TranscriptionConfig.makeService()   // real relay if configured, else fake
        var recorder: AudioRecording = AVAudioRecorderService()
        #if DEBUG
        // The retained-failure surface, drivable by a UI test without a microphone or a network.
        if let stand_in = DebugVoice.service(), let mic = DebugVoice.recorder() {
            service = stand_in
            recorder = mic
        }
        #endif
        // Captured now: the tip teaches a round trip that actually happened, so the offline fake must
        // not trigger it (`WritingEducation.voiceTranscriptionSucceeded`).
        let sendsOffDevice = service.sendsAudioOffDevice
        let capture = VoiceCaptureModel(
            recorder: recorder,
            service: service,
            // Carried only so a recording recovered *after* this editing session is gone can say,
            // before it is retried, that its transcript will arrive as a new note.
            origin: .note
        ) { text in
            let cursor = model.insertVoiceTranscript(text, atUTF16: capturedInsertOffset)
            bodySelection = NSRange(location: cursor, length: 0)
            // Only ever called on success, so a failed, cancelled, or consent-declined capture
            // cannot reach this — which is exactly the sequencing the tip requires.
            education.voiceTranscriptionSucceeded(sentOffDevice: sendsOffDevice)
        }
        voice = capture
        Task { await capture.begin() }
    }

    private func endVoice() {
        voice = nil
        // Reading stays reading: only give the keyboard back if the user was editing beforehand.
        if refocusBodyAfterVoice { bodyFocused = true }
    }
}
