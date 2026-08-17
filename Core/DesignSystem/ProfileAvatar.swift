import SwiftUI

/// Circular avatar showing the user's initial, or a person glyph when no name is set.
/// Used in the Home header and the Profile screen.
struct ProfileAvatar: View {
    let name: String
    var size: CGFloat = 30

    private var initial: String {
        let t = name.trimmingCharacters(in: .whitespaces)
        guard let first = t.first else { return "" }
        return String(first).uppercased()
    }

    var body: some View {
        ZStack {
            Circle().fill(Color.ds.accent.opacity(0.15))
            if initial.isEmpty {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(Color.ds.accent)
            } else {
                Text(initial)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(Color.ds.accent)
            }
        }
        .frame(width: size, height: size)
    }
}
