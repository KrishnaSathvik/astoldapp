import SwiftUI

/// Brand mark = feather glyph (SF Symbol placeholder for the real asset) + serif wordmark logotype.
/// The serif is a brand logotype only, NOT a UI text font. See RULES.md §4, docs/03-design-system.md §0.
struct AppMark: View {
    var showsWordmark = true
    var markSize: CGFloat = 44

    var body: some View {
        VStack(spacing: DSSpacing.s4) {
            FeatherMark(size: markSize)
            if showsWordmark {
                Text("As Told")
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(Color.ds.textPrimary)
            }
        }
    }
}

#Preview { AppMark().frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.ds.canvas) }
