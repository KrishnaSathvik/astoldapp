import SwiftUI

/// Opaque cover shown when the app is not active and lock is enabled — hides note content from the
/// app-switcher snapshot. Shows only the brand mark, never readable notes (RULES.md §3).
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color.ds.canvas.ignoresSafeArea()
            AppMark(markSize: 40)
        }
    }
}
