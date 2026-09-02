import SwiftUI

/// The Aurora ribbon — the HUD's hero visual. A flowing monochrome ribbon inside a translucent
/// capsule that reacts to the live voice level, rendered with `TimelineView(.animation) + Canvas`
/// (verified 60fps for a panel this small, no Metal, no availability gating at the .macOS(.v14) target).
///
/// It draws purely from `HUDViewModel` — a `HUDPhase` and a 0…1 `level`. Monochrome, with a single
/// ice accent that only shows in motion (the stroke shifts white → ice as you get louder). No
/// focusable controls, so nothing here can ever become first responder and break the panel.
struct AuroraView: View {
    @State var model: HUDViewModel

    /// The ice accent, only ever seen when the ribbon moves.
    private static let accent = Color(red: 0.66, green: 0.85, blue: 1.0)
    private static let amber = Color(red: 0.90, green: 0.69, blue: 0.44)

    /// When the current phase started, for one-shot animations (done pulse, deflate).
    @State private var phaseStart = Date()
    /// Drives the spring-up when a dictation starts and the settle-down when it ends.
    @State private var visible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: model.phase == .hidden)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date
                let t = now.timeIntervalSinceReferenceDate
                let elapsed = now.timeIntervalSince(phaseStart)
                switch model.phase {
                case .listening, .appear:
                    let lvl = pow(Double(model.level), 0.7)   // lift low/mid voice into the visible range
                    drawRibbons(ctx, size, t: t, level: lvl)
                    drawRim(ctx, size, level: lvl)
                case .thinking:
                    drawThinking(ctx, size, t: t)
                case .done:
                    drawDone(ctx, size, elapsed: elapsed)
                case .deflate:
                    drawDeflate(ctx, size, elapsed: elapsed)
                case .hidden:
                    break
                }
            }
        }
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
        .padding(14)
        .scaleEffect(visible ? 1 : 0.9)
        .offset(y: visible ? 0 : 12)
        .opacity(visible ? 1 : 0)
        .onAppear { visible = model.phase != .hidden }
        .onChange(of: model.phase) { _, newPhase in
            phaseStart = Date()
            // Spring the capsule up when a dictation starts; settle it down when it ends.
            withAnimation(.spring(response: 0.34, dampingFraction: 0.7)) {
                visible = (newPhase != .hidden)
            }
        }
    }

    // MARK: - Listening: three flowing ribbons

    private func drawRibbons(_ ctx: GraphicsContext, _ size: CGSize, t: Double, level: Double) {
        let midY = size.height / 2
        let w = Double(size.width)
        for layer in 0..<3 {
            var path = Path()
            let amp = (5 + level * 20) * (1 - Double(layer) * 0.22)
            let speed = 1.4 + Double(layer) * 0.5
            let freq = 1.5 + Double(layer) * 0.6
            let phase = t * speed + Double(layer) * 2
            var first = true
            var x = 0.0
            while x <= w {
                let nx = (x / w) * .pi * 2
                let y = midY
                    + sin(nx * freq + phase) * amp
                    + sin(nx * 3.1 - phase * 0.7) * amp * 0.3
                    + Double(layer - 1) * 4
                let p = CGPoint(x: x, y: y)
                if first { path.move(to: p); first = false } else { path.addLine(to: p) }
                x += 3
            }
            // White when quiet, ice when loud — the accent only appears in motion.
            let color = Color(red: 1 - 0.34 * level, green: 1 - 0.15 * level, blue: 1.0)
            let opacity = max(0, 0.28 + level * 0.6 - Double(layer) * 0.08)
            let width = 2.2 - Double(layer) * 0.5
            if level > 0.15 && layer == 0 {
                // A soft glow under the top ribbon when there's real signal.
                ctx.drawLayer { g in
                    g.addFilter(.blur(radius: 3))
                    g.stroke(path, with: .color(Self.accent.opacity(opacity * 0.8)), lineWidth: width + 1)
                }
            }
            ctx.stroke(path, with: .color(color.opacity(opacity)), lineWidth: width)
        }
    }

    /// A rim highlight around the capsule that brightens with volume.
    private func drawRim(_ ctx: GraphicsContext, _ size: CGSize, level: Double) {
        guard level > 0.05 else { return }
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
        let rim = Capsule().path(in: rect)
        ctx.stroke(rim, with: .color(Self.accent.opacity(level * 0.5)), lineWidth: 1.2)
    }

    // MARK: - Thinking: a calm swirl of dots

    private func drawThinking(_ ctx: GraphicsContext, _ size: CGSize, t: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = 12.0
        for i in 0..<4 {
            let a = t * 1.8 + Double(i) * (.pi / 2)
            let x = center.x + cos(a) * r
            let y = center.y + sin(a) * r * 0.7
            let fade = 0.35 + 0.65 * (0.5 + 0.5 * sin(a))
            let dot = Path(ellipseIn: CGRect(x: x - 2.3, y: y - 2.3, width: 4.6, height: 4.6))
            ctx.fill(dot, with: .color(Self.accent.opacity(fade)))
        }
    }

    // MARK: - Done: one confident pulse + a streak toward the field

    private func drawDone(_ ctx: GraphicsContext, _ size: CGSize, elapsed: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let p = min(1, elapsed / 0.42)

        // Expanding ring.
        let r = 5 + p * 22
        let ring = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.stroke(ring, with: .color(Self.accent.opacity((1 - p) * 0.9)), lineWidth: 2)

        // Solid core.
        let core = Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7))
        ctx.fill(core, with: .color(Color.primary.opacity(0.9 * (1 - p * 0.5))))

        // Streak toward the cursor: a short accent dash flying up out of the capsule, so the paste
        // feels *placed* rather than teleported.
        let streakY = center.y - p * (center.y + 18)
        var streak = Path()
        streak.move(to: CGPoint(x: center.x, y: streakY + 8))
        streak.addLine(to: CGPoint(x: center.x, y: streakY))
        ctx.stroke(streak, with: .color(Self.accent.opacity((1 - p) * 0.85)), lineWidth: 2)
    }

    // MARK: - Deflate: a flat amber line — nothing heard / target lost

    private func drawDeflate(_ ctx: GraphicsContext, _ size: CGSize, elapsed: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let grow = min(1, elapsed / 0.14)
        let fade = elapsed > 0.28 ? max(0, 1 - (elapsed - 0.28) / 0.16) : 1
        let half = 22.0 * grow
        var line = Path()
        line.move(to: CGPoint(x: center.x - half, y: center.y))
        line.addLine(to: CGPoint(x: center.x + half, y: center.y))
        ctx.stroke(line, with: .color(Self.amber.opacity(0.9 * fade)), lineWidth: 3)
    }
}
