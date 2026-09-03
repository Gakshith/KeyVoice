import SwiftUI
import KeyVoiceDesign

/// The Living HUD — a capsule of real **Liquid Glass** (macOS 26, via the design kit's `glassSurface`)
/// with the **Aurora** drawn inside by a SwiftUI `Canvas`. Porting the concept from `hud-concepts.html`
/// to Canvas means the HUD ships **no Metal shader, no `.metallib`, and no resource bundle** — which
/// also removes the clean-Mac packaging crash the audit flagged (P0 · SHIP).
///
/// It draws purely from `HUDViewModel` (a `HUDPhase` + a live 0…1 `level`) and honors Reduce Motion.
/// Focus-safety is unchanged — no focusable controls, so nothing here can become first responder.
struct AuroraView: View {
    @State var model: HUDViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var start = Date()
    @State private var phaseStart = Date()
    @State private var visible = false

    // The concept palette: a single ice accent, brighter for confident moments, amber only for "nothing".
    private static let ice = Color(red: 0.663, green: 0.847, blue: 1.0)        // #a9d8ff
    private static let iceStrong = Color(red: 0.863, green: 0.937, blue: 1.0)  // #dcefff
    private static let amber = Color(red: 0.906, green: 0.690, blue: 0.443)    // #e7b071

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: model.phase == .hidden || reduceMotion)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSince(start)
                    let elapsed = timeline.date.timeIntervalSince(phaseStart)
                    draw(ctx, size: size, t: reduceMotion ? 0 : t, elapsed: elapsed)
                }
            }
        }
        .clipShape(Capsule())
        .glassSurface(shape: Capsule())          // real Liquid Glass behind the light
        .padding(8)
        .scaleEffect(visible ? 1 : 0.9)
        .offset(y: visible ? 0 : 12)
        .opacity(visible ? 1 : 0)
        .onAppear { visible = model.phase != .hidden }
        .onChange(of: model.phase) { _, newPhase in
            phaseStart = Date()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                visible = (newPhase != .hidden)
            }
        }
    }

    // MARK: - Drawing

    private func draw(_ ctx: GraphicsContext, size: CGSize, t: TimeInterval, elapsed: TimeInterval) {
        switch model.phase {
        case .hidden:
            break
        case .appear, .listening:
            drawAurora(ctx, size: size, t: t, level: Double(max(0, min(1, model.level))))
        case .thinking:
            drawThinking(ctx, size: size, t: t)
        case .done:
            drawDone(ctx, size: size, elapsed: elapsed)
        case .deflate:
            drawFlatline(ctx, size: size, elapsed: elapsed)
        }
    }

    /// Three flowing ribbons whose amplitude tracks the live voice level.
    private func drawAurora(_ ctx: GraphicsContext, size: CGSize, t: TimeInterval, level: Double) {
        var ctx = ctx
        ctx.addFilter(.shadow(color: Self.ice.opacity(0.55), radius: 2 + level * 5))
        let my = size.height / 2
        for k in 0..<3 {
            var path = Path()
            let amp = (1.5 + level * 9) * (1 - Double(k) * 0.22)
            let ph = t * (0.8 + Double(k) * 0.5) + Double(k) * 2
            let freq = 1.6 + Double(k) * 0.5
            var x = 6.0
            while x <= size.width - 6 {
                let nx = (x / size.width) * 2 * .pi
                let y = my + sin(nx * freq + ph) * amp + sin(nx * 3.2 - ph * 0.7) * amp * 0.3 + (Double(k) - 1) * 2.5
                if x == 6 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                x += 3
            }
            let opacity = max(0.14, 0.32 + level * 0.6 - Double(k) * 0.08)
            ctx.stroke(path, with: .color(Self.ice.opacity(opacity)),
                       style: StrokeStyle(lineWidth: 1.8 - Double(k) * 0.4, lineCap: .round))
        }
    }

    /// A calm swirl of dots while transcription + cleanup run.
    private func drawThinking(_ ctx: GraphicsContext, size: CGSize, t: TimeInterval) {
        var ctx = ctx
        ctx.addFilter(.shadow(color: Self.ice.opacity(0.5), radius: 3))
        let mx = size.width / 2, my = size.height / 2, radius = 8.0, n = 4
        for i in 0..<n {
            let a = t * 1.8 + Double(i) * (2 * .pi / Double(n))
            let x = mx + cos(a) * radius, y = my + sin(a) * radius * 0.7
            let fade = 0.35 + 0.65 * (0.5 + 0.5 * sin(a))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                     with: .color(Self.ice.opacity(fade)))
        }
    }

    /// One confident expanding pulse when text lands.
    private func drawDone(_ ctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let p = min(1, elapsed / 0.5)
        let mx = size.width / 2, my = size.height / 2
        let r = 4 + p * 18, alpha = 1 - p
        ctx.stroke(Path(ellipseIn: CGRect(x: mx - r, y: my - r, width: 2 * r, height: 2 * r)),
                   with: .color(Self.iceStrong.opacity(alpha * 0.9)), lineWidth: 2)
        ctx.fill(Path(ellipseIn: CGRect(x: mx - 2.5, y: my - 2.5, width: 5, height: 5)),
                 with: .color(Self.iceStrong.opacity(0.8)))
    }

    /// Nothing heard / target lost / error → deflate to a short amber line.
    private func drawFlatline(_ ctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let w = min(1, elapsed / 0.3) * min(60, size.width * 0.5)
        let mx = size.width / 2, my = size.height / 2
        var path = Path()
        path.move(to: CGPoint(x: mx - w / 2, y: my))
        path.addLine(to: CGPoint(x: mx + w / 2, y: my))
        var ctx = ctx
        ctx.addFilter(.shadow(color: Self.amber.opacity(0.6), radius: 3))
        ctx.stroke(path, with: .color(Self.amber), style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}
