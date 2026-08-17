import SwiftUI

/// Circular avatar for the Profile screen — the user's initial (or a person glyph) on a soft
/// accent-tinted disc. Subtle, not a heavy solid fill.
struct ProfileAvatar: View {
    let name: String
    var size: CGFloat = 72

    private var initial: String {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard let first = t.first else { return "" }
        return String(first).uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.ds.accent.opacity(0.14))
            if initial.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(Color.ds.accent)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(Color.ds.accent)
            }
        }
        .frame(width: size, height: size)
    }
}
