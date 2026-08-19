import SwiftUI

/// One-time card taught after the **first successful** transcription, next to the microphone that
/// just produced it.
///
/// Two examples, not the nine-command vocabulary. Someone who has spoken one note into the app has
/// exactly one question — "can I do more than dictate a paragraph?" — and two concrete sentences
/// answer it. The full list lives behind the editor's `?`, which is where a person who wants it will
/// look. Reciting all nine here would be the onboarding wall this design exists to avoid.
struct VoiceStructureTip: View {
    var onDismiss: () -> Void

    private static let examples = [
        "“Heading. Alaska trip.”",
        "“Checklist. Book hotel. Next item. Rent car.”",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s3) {
            Text("You can shape notes while speaking")
                .font(.ds.noteTitle)
                .foregroundStyle(Color.ds.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                Text("Try saying:")
                    .font(.ds.caption)
                    .foregroundStyle(Color.ds.textSecondary)
                ForEach(Self.examples, id: \.self) { example in
                    Text(example)
                        .font(.ds.preview)
                        .foregroundStyle(Color.ds.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button("Got it") { onDismiss() }
                .font(.ds.noteTitle)
                .foregroundStyle(Color.ds.accent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityHint("Dismisses this tip. It will not appear again.")
        }
        .padding(DSSpacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ds.surface, in: RoundedRectangle(cornerRadius: DSRadius.large))
        // A tip is not the note. It sits above the writing without covering it, and never takes focus
        // away from text the user just dictated.
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("You can shape notes while speaking")
    }
}
