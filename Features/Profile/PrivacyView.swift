import SwiftUI

/// Where the app's user-facing privacy links live. The policy is hosted, not bundled, so it can be
/// corrected without shipping a build — App Review 5.1.1(i) requires the link to be reachable from
/// inside the app as well as from App Store Connect.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://astold.app/privacy")!
}

/// Privacy screen. The copy reflects the *actual* architecture (docs/01-product-requirements.md §11,
/// RULES.md §3) — it must stay true to how the app really behaves, layer by layer.
///
/// Deliberately free of absolutes. "Nothing is logged", "nothing ever leaves your phone" and
/// "100% private" are all broader than the implementation, and a privacy page that overclaims is
/// worse than one that says less (docs/08-positioning-marketing.md §5).
struct PrivacyView: View {
    private struct Point: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private let points: [Point] = [
        .init(title: "Your notes stay on your device",
              body: "Notes are stored locally on your iPhone. There is no cloud copy and no sync. The name and settings on your profile are local too."),
        .init(title: "No sign-in",
              body: "As Told never asks you to create an account or sign in. There is nothing tying your notes to an identity."),
        .init(title: "Voice leaves the device only when you ask",
              body: "A recording is sent for transcription only when you choose to transcribe it, and only after you agree the first time. As Told sends it through its own transcription service to OpenAI, which turns it into text. Nothing else from your note goes with it."),
        .init(title: "What isn't kept",
              body: "As Told doesn't keep your recording or your transcript once the request finishes, and no audio, transcript, note text, or search query is written to its logs. The service that hosts it handles ordinary connection information, such as an IP address, to keep it running and to prevent abuse."),
        .init(title: "Your words stay yours",
              body: "Speech is transcribed in the words you actually said. Punctuation and capitalization are added so it reads naturally — nothing is translated, summarized, rewritten, or grammar-corrected."),
        .init(title: "Lock it down",
              body: "You can optionally require Face ID, or your device passcode, to open the app. It uses Apple's own authentication and never sees your biometrics. When it's on, your notes are covered in the app switcher and revealed only after you unlock."),
        .init(title: "No ads, no tracking",
              body: "As Told carries no advertising, no tracking, and no analytics SDK. Nothing you write is used to build a profile of you."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s6) {
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: DSSpacing.s2) {
                        Text(point.title)
                            .font(.ds.noteTitle)
                            .foregroundStyle(Color.ds.textPrimary)
                        Text(point.body)
                            .font(.ds.preview)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }

                VStack(spacing: 0) {
                    NavigationLink { VoiceTranscriptionView() } label: {
                        LinkRow(title: "Voice Transcription", external: false)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Color.ds.textTertiary.opacity(0.12))
                        .frame(height: 0.5)

                    // Opens in the system browser. An embedded web view would be a second, worse
                    // browser inside a notes app.
                    Link(destination: AppLinks.privacyPolicy) {
                        LinkRow(title: "Privacy Policy", external: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the full privacy policy in your browser")
                }
                .padding(.top, DSSpacing.s2)

                Spacer(minLength: DSSpacing.s10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.screenH)
        }
        .scrollIndicators(.hidden)
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Permanent, informational explanation of the voice round trip — the same facts the one-time
/// disclosure states, with the boundary spelled out. Deliberately carries **no toggle**: the
/// one-time consent flow (`TranscriptionConsent`) is the single source of truth for the decision,
/// and a second switch here would be a second answer to the same question.
struct VoiceTranscriptionView: View {
    private struct Point: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private let points: [Point] = [
        .init(title: "Where your recording goes",
              body: "When you choose to transcribe a recording, As Told sends that recording securely to OpenAI through the As Told transcription service. No title, existing note text, search history, or other note content is included."),
        .init(title: "What it's used for",
              body: "The recording is used only to produce your transcript, which is inserted into your note as ordinary, editable text."),
        .init(title: "What happens afterwards",
              body: "The recording on your iPhone is deleted once the transcript arrives. As Told doesn't keep the recording or the transcript on its side after the request finishes."),
        .init(title: "You're asked first",
              body: "The first time a recording would leave your device, As Told tells you and waits. If you decline, the recording is deleted and nothing is sent."),
        .init(title: "Keeping it from being abused",
              body: "The transcription service checks that a request comes from a genuine copy of As Told, using Apple's App Attest. It identifies the app, not you."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.s6) {
                ForEach(points) { point in
                    VStack(alignment: .leading, spacing: DSSpacing.s2) {
                        Text(point.title)
                            .font(.ds.noteTitle)
                            .foregroundStyle(Color.ds.textPrimary)
                        Text(point.body)
                            .font(.ds.preview)
                            .foregroundStyle(Color.ds.textSecondary)
                    }
                }

                Spacer(minLength: DSSpacing.s10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DSSpacing.screenH)
        }
        .scrollIndicators(.hidden)
        .background(Color.ds.canvas.ignoresSafeArea())
        .navigationTitle("Voice Transcription")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Chromeless row matching Profile's treatment — no iOS cards (docs/03-design-system.md §4.6).
private struct LinkRow: View {
    let title: String
    let external: Bool

    var body: some View {
        HStack(spacing: DSSpacing.s3) {
            Text(title)
                .font(.ds.editorBody)
                .foregroundStyle(Color.ds.textPrimary)
            Spacer()
            Image(systemName: external ? "arrow.up.right" : "chevron.right")
                .font(.footnote)
                .foregroundStyle(Color.ds.textTertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
