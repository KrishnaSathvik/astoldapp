import SwiftUI

/// Day-group header: Today / Yesterday / localized date.
struct DateGroupHeader: View {
    let day: Date
    var body: some View {
        Text(dayLabel(for: day))
            .font(.ds.groupTitle)
            .foregroundStyle(Color.ds.textPrimary)
            .padding(.top, DSSpacing.s6)
            .accessibilityAddTraits(.isHeader)
    }
}
