import SwiftUI

/// Minimal feather/quill brand glyph drawn in SwiftUI (placeholder for the final asset).
/// Matches docs/design-reference/screens-overview.png. Renders at any size, tint follows foreground.
struct FeatherMark: View {
    var size: CGFloat = 48

    var body: some View {
        Canvas { ctx, rect in
            let w = rect.width, h = rect.height
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }

            // Feather vane (leaf-like outline), tilted.
            var vane = Path()
            vane.move(to: p(0.30, 0.92))                 // quill tip (bottom-left)
            vane.addQuadCurve(to: p(0.86, 0.10),          // top-right tip
                              control: p(0.30, 0.30))
            vane.addQuadCurve(to: p(0.30, 0.92),          // back down the left edge
                              control: p(0.86, 0.62))

            let tint = GraphicsContext.Shading.color(Color.ds.accent)
            ctx.fill(vane, with: tint)

            // Central rachis (shaft) + a couple of barb hints, drawn in the canvas color to carve detail.
            var shaft = Path()
            shaft.move(to: p(0.30, 0.92))
            shaft.addQuadCurve(to: p(0.82, 0.16), control: p(0.46, 0.52))
            ctx.stroke(shaft, with: .color(Color.ds.canvas), lineWidth: max(1, size * 0.03))

            var barbs = Path()
            barbs.move(to: p(0.44, 0.60)); barbs.addLine(to: p(0.66, 0.42))
            barbs.move(to: p(0.40, 0.70)); barbs.addLine(to: p(0.58, 0.54))
            barbs.move(to: p(0.52, 0.50)); barbs.addLine(to: p(0.72, 0.34))
            ctx.stroke(barbs, with: .color(Color.ds.canvas), lineWidth: max(1, size * 0.022))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    FeatherMark(size: 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ds.canvas)
}
