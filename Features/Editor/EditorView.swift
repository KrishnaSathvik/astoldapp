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

    private var isCapturing: Bool { voice != nil }
    /// True while the user is actually editing (a field owns the keyboard), false while reading.
    private var isEditing: Bool { bodyFocused || titleFocused }

    private var dateText: String {
        let df = DateFormatter(); df.dateFormat = "MMMM d, yyyy · h:mm a"
        return df.string(from: note.createdAt).uppercased()
    }

    private func close() {
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
                Task { try? await Task.sleep(for: .seconds(1.5)); voice?.done() }
            }
            #endif
        }
        .onDisappear {
            // Back is not a cancel. A running recording is finished and transcribed, exactly as
            // backgrounding, a phone call, and the duration cap already do — leaving used to delete
            // the audio, so tapping Back mid-sentence destroyed everything the user had said.
            // `finishOnLeave` stops the microphone either way, so nothing is left hot or on disk.
            voice?.finishOnLeave()
            voice = nil
            model?.finish()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model?.flush() }
            // Recording cannot continue once the app is suspended, so finish the capture with the
            // audio already on disk rather than stranding it.
            if phase == .background, voice?.phase == .recording { voice?.done() }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { close() } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").fontWeight(.semibold)
                        Text("Notes")
                    }
                    .foregroundStyle(Color.ds.accent)
                }
                .accessibilityLabel("Back to notes")
            }
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
            dateText: dateText,
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
                                              titleFocused: titleFocused) != .hidden
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
                    mode: .resolve(bodyFocused: bodyFocused, titleFocused: titleFocused),
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

    private func startVoice(_ model: EditorModel) {
        // Where the transcript will land is decided *now*, before recording, and the recording owns
        // that anchor (docs/04-voice-transcription.md §8):
        //  - caret in the body  → insert at the caret
        //  - reading, no caret  → append to the end of the note
        refocusBodyAfterVoice = bodyFocused
        capturedInsertOffset = bodyFocused
            ? bodySelection.location
            : (model.body as NSString).length

        let service = TranscriptionConfig.makeService()   // real relay if configured, else fake
        // Captured now: the tip teaches a round trip that actually happened, so the offline fake must
        // not trigger it (`WritingEducation.voiceTranscriptionSucceeded`).
        let sendsOffDevice = service.sendsAudioOffDevice
        let capture = VoiceCaptureModel(
            recorder: AVAudioRecorderService(),
            service: service
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
