import SwiftUI

/// The luminous backdrop the whole Hub floats on. Liquid Glass is *refraction* — a `glassEffect`
/// over flat system-dark just reads as a dark rectangle. This gives every glass surface something
/// bright and moving to bend: a night gradient with two slowly drifting ice/cyan glows. Cheap —
/// one GPU `Canvas`, redrawn at 30fps.
public struct GlassBackdrop: View {
    public init() {}

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // Night gradient base (matches the app icon's cool night sky).
                let base = Gradient(colors: [
                    Color(red: 0.07, green: 0.12, blue: 0.24),
                    Color(red: 0.03, green: 0.04, blue: 0.09),
                ])
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        base,
                        startPoint: CGPoint(x: size.width / 2, y: 0),
                        endPoint: CGPoint(x: size.width / 2, y: size.height)
                    )
                )

                // Ice glow drifting near the top-leading corner.
                glow(&ctx,
                     cx: size.width * (0.30 + 0.06 * CGFloat(sin(t * 0.15))),
                     cy: size.height * (0.20 + 0.05 * CGFloat(cos(t * 0.11))),
                     r: max(size.width, size.height) * 0.62,
                     color: Color(red: 0.30, green: 0.62, blue: 1.0), a: 0.32)

                // Cooler cyan glow drifting near the bottom-trailing corner.
                glow(&ctx,
                     cx: size.width * (0.78 + 0.05 * CGFloat(cos(t * 0.13))),
                     cy: size.height * (0.84 + 0.05 * CGFloat(sin(t * 0.09))),
                     r: max(size.width, size.height) * 0.55,
                     color: Color(red: 0.36, green: 0.80, blue: 0.92), a: 0.24)
            }
        }
        .ignoresSafeArea()
    }

    /// A soft radial bloom that fades to fully transparent at its edge.
    private func glow(_ ctx: inout GraphicsContext, cx: CGFloat, cy: CGFloat, r: CGFloat, color: Color, a: Double) {
        let grad = Gradient(colors: [color.opacity(a), color.opacity(0)])
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
            with: .radialGradient(grad, center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r)
        )
    }
}
