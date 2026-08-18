import SwiftUI

/// The mic entry control in the editor. See docs/03-design-system.md §4.7–4.8.
struct VoiceButton: View {
    var action: () -> Void
    /// True when there is no caret in the body, so the transcript will be appended to the end.
    var appendsToEnd: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic")
                .font(.title3)
                .foregroundStyle(Color.ds.textPrimary)
                .frame(width: 48, height: 48)
                .background(.thinMaterial, in: Circle())
        }
        .accessibilityLabel("Start recording")
        .accessibilityHint(appendsToEnd
            ? "Adds what you say to the end of this note"
            : "Adds what you say at the cursor")
    }
}
