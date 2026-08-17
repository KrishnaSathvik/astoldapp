import SwiftUI

/// Motion tokens. Prefer these over hardcoded timing. See docs/03-design-system.md §12.
enum DSMotion {
    static let fast = Animation.easeInOut(duration: 0.16)
    static let standard = Animation.easeInOut(duration: 0.25)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.85)
}
