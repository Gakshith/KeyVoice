import SwiftUI
import KeyVoiceDesign

/// The Aurora HUD — native. A capsule of real **Liquid Glass** (macOS 26 `glassEffect`, via the
/// design kit's `glassSurface`, with a material fallback) that refracts the desktop behind the
/// floating panel, with the **Aurora** rendered inside by a Metal shader driven by the live voice
/// level. The shader is precompiled to a metallib (SwiftPM won't compile `.metal`) and loaded here.
///
/// It draws purely from `HUDViewModel` (a `HUDPhase` + a 0…1 `level`). Focus-safety is unchanged —
/// no focusable controls, so nothing here can become first responder.
struct AuroraView: View {
    @State var model: HUDViewModel

    @State private var start = Date()
    @State private var phaseStart = Date()
    @State private var visible = false

    /// The precompiled Metal library, loaded once. Nil only if the resource is missing (then we fall
    /// back to a plain glow so the HUD is never broken).
    private static let library: ShaderLibrary? = {
        guard let url = Bundle.module.url(forResource: "default", withExtension: "metallib") else { return nil }
        return ShaderLibrary(url: url)
    }()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: model.phase == .hidden)) { timeline in
                let t = Float(timeline.date.timeIntervalSince(start))
                let elapsed = timeline.date.timeIntervalSince(phaseStart)
                aurora(size: geo.size, time: t, u: uniforms(elapsed: elapsed))
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

    @ViewBuilder
    private func aurora(size: CGSize, time: Float, u: Uniforms) -> some View {
        if let lib = Self.library {
            Rectangle()
                .fill(.white)
                .colorEffect(lib.aurora(
                    .float2(size),
                    .float(time),
                    .float(u.level), .float(u.think), .float(u.done), .float(u.amber)
                ))
        } else {
            // Shader unavailable → a simple ice glow so the HUD still reads.
            Rectangle().fill(Color(red: 0.66, green: 0.85, blue: 1.0).opacity(Double(u.level) * 0.7))
        }
    }

    private struct Uniforms { var level: Float; var think: Float; var done: Float; var amber: Float }

    private func uniforms(elapsed: TimeInterval) -> Uniforms {
        switch model.phase {
        case .listening, .appear:
            return Uniforms(level: max(0, min(1, model.level)), think: 0, done: 0, amber: 0)
        case .thinking:
            return Uniforms(level: 0, think: 1, done: 0, amber: 0)
        case .done:
            return Uniforms(level: 0, think: 0, done: Float(min(1, elapsed / 0.5)), amber: 0)
        case .deflate:
            return Uniforms(level: 0, think: 0, done: 0, amber: 1)
        case .hidden:
            return Uniforms(level: 0, think: 0, done: 0, amber: 0)
        }
    }
}
