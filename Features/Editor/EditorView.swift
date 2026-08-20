import SwiftUI
import SwiftData

/// Plain-text editor: date, optional title, body. No Save, no formatting toolbar (RULES.md §4).
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


    /// Drives the Style menu: reads the selection's current style so the menu can check it, and
    /// applies a chosen one through the body's shared `DocumentAction` path.
    ///
    /// The getter is `nil` when the selection spans two different styles, which is what leaves the
    /// menu with nothing checked. The setter refuses a no-op, because re-applying the style a line
    /// already has would still be a text edit and would still cost the writer an undo step.
    private var styleSelection: Binding<BlockStyle?> {
        Binding(
            get: { model.map { BlockStyle.current(in: $0.body, selection: bodySelection) } ?? nil },
            set: { chosen in
                guard let chosen,
                      chosen != model.flatMap({ BlockStyle.current(in: $0.body, selection: bodySelection) })
                else { return }
                bodyActions.apply(chosen)
            }
        )
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
            // The Style control (docs/02-features.md Milestone B2). One contextual button, shown only
            // while the *body* has the caret — styling a title is meaningless, and a control that
            // survived into the reading state would be the persistent ribbon RULES.md §1 refuses.
            //
            // A menu, not a sheet, and that is a behavioral requirement rather than a taste: a sheet
            // resigns first responder, so the keyboard would drop and the selection the style applies
            // to would have to be restored afterwards. A menu leaves both alone, which is what lets a
            // writer keep the four lines they selected and just pick a style.
            if bodyFocused {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Style", selection: styleSelection) {
                            ForEach(BlockStyle.allCases) { style in
                                Text(style.name).tag(Optional(style))
                            }
                        }
                        .pickerStyle(.inline)
                        Divider()
                        // The old standalone `?` folded in: reference material one tap deeper, where
                        // losing the keyboard to a sheet costs nothing because nothing is being applied.
                        Button("Writing help…") { showsWritingHelp = true }
                    } label: {
                        Image(systemName: "textformat")
                            .foregroundStyle(Color.ds.accent)
                    }
                    .accessibilityLabel("Style")
                }
            }
        }
        .sheet(isPresented: $showsWritingHelp) { WritingHelpSheet() }
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
            bodyPlaceholder: "Start writing…"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) { voiceLayer(model) }
        .padding(.horizontal, DSSpacing.screenH)
        .padding(.top, DSSpacing.s4)
        .animation(DSMotion.fast, value: isEditing)
    }

    @ViewBuilder private func voiceLayer(_ model: EditorModel) -> some View {
        if let voice {
            RecordingPanel(model: voice) { endVoice() }
                .padding(.bottom, DSSpacing.s4)
        } else {
            VStack(spacing: DSSpacing.s3) {
                // Sits above the microphone that just produced the transcript, after the capture UI
                // has gone — never stacked on the consent sheet, because it is only reachable once a
                // transcription has actually succeeded.
                if education.showsVoiceStructureTip {
                    VoiceStructureTip { education.dismissVoiceStructureTip() }
                }
                HStack {
                    Spacer()
                    VoiceButton(action: { startVoice(model) }, appendsToEnd: !bodyFocused)
                }
            }
            .padding(.bottom, DSSpacing.s4)
            .animation(DSMotion.fast, value: education.showsVoiceStructureTip)
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
