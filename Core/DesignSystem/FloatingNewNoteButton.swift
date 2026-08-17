import SwiftUI

/// Quiet, reachable New Note control. SF Symbol `plus`, filled accent circle, ≥44pt hit area.
/// See docs/03-design-system.md §4.3.
struct FloatingNewNoteButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.ds.accent, in: Circle())
        }
        .accessibilityLabel("New note")
    }
}
