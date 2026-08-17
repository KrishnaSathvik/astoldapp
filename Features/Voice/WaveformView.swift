import SwiftUI

/// Simple live level waveform: a row of bars whose heights follow recent input levels.
struct WaveformView: View {
    var levels: [Float]          // most-recent last, values 0...1
    var tint: Color = .white

    var body: some View {
        GeometryReader { geo in
            let count = max(levels.count, 1)
            let barWidth = max(2, (geo.size.width - CGFloat(count - 1) * 2) / CGFloat(count))
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, lvl in
                    Capsule()
                        .fill(tint.opacity(0.9))
                        .frame(width: barWidth,
                               height: max(3, CGFloat(lvl) * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
