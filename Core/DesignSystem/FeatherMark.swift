import SwiftUI

/// The As Told feather — the same mark as the app icon, so the brand reads identically on the icon,
/// the Welcome/About/Lock screens, and the marketing site (docs/03-design-system.md §0, RULES.md §4).
///
/// Shipped as a **template** image: the artwork lives in the asset's alpha channel (the feather's
/// chalky texture and its pale rachis line are opacity, not colour), so a single asset tints to
/// `Color.ds.accent` and inverts correctly in Dark Mode instead of going dark-on-dark.
struct FeatherMark: View {
    /// Height of the mark. Width follows the artwork's natural aspect (~0.65).
    var size: CGFloat = 48

    var body: some View {
        Image("FeatherMark")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .foregroundStyle(Color.ds.accent)
            .accessibilityHidden(true)
    }
}

#Preview("Light") {
    FeatherMark(size: 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.canvas)
}

#Preview("Dark") {
    FeatherMark(size: 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.canvas)
        .preferredColorScheme(.dark)
}
