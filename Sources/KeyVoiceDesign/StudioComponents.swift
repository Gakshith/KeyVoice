import SwiftUI

// Shared primitives for the KeyVoice Studio surface (warm paper + voice spectrum).
// Screens compose these so the look stays consistent as the app grows.

/// The serif display face. SwiftUI's `.serif` design gives New York on macOS — warm, editorial,
/// no font bundling required. Swap for bundled Fraunces later if desired.
public extension Font {
    static func studioSerif(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

/// A sidebar navigation row. Selected = white card with an accent glyph; idle = quiet, hover-lit.
public struct StudioNavItem: View {
    private let title: String
    private let systemImage: String
    private let selected: Bool
    private let action: () -> Void
    @State private var hovering = false

    public init(_ title: String, systemImage: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.selected = selected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 18)
                    .foregroundStyle(selected ? KeyVoiceTokens.Colors.accent : KeyVoiceTokens.Colors.text2)
                Text(title)
                    .font(.system(size: 14.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(selected ? KeyVoiceTokens.Colors.text : KeyVoiceTokens.Colors.text2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected ? KeyVoiceTokens.Colors.card : (hovering ? KeyVoiceTokens.Colors.paper2 : .clear))
                    .overlay {
                        if selected {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(KeyVoiceTokens.Colors.line, lineWidth: 1)
                        }
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A big serif stat: value (+ optional unit) over an uppercase label.
public struct StudioStat: View {
    private let value: String
    private let unit: String?
    private let label: String

    public init(value: String, unit: String? = nil, label: String) {
        self.value = value
        self.unit = unit
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.studioSerif(34))
                    .monospacedDigit()
                    .foregroundStyle(KeyVoiceTokens.Colors.text)
                if let unit {
                    Text(unit)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeyVoiceTokens.Colors.fog)
                }
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(KeyVoiceTokens.Colors.fog)
        }
    }
}

/// A plain warm card container (white fill, hairline border, rounded).
public struct StudioCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    public init(padding: CGFloat = 22, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }
    public var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(KeyVoiceTokens.Colors.card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(KeyVoiceTokens.Colors.line, lineWidth: 1)
                    }
            }
    }
}

/// An uppercase section label (e.g. "TODAY").
public struct StudioSectionLabel: View {
    private let text: String
    public init(_ text: String) { self.text = text }
    public var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(KeyVoiceTokens.Colors.fog)
    }
}

/// The living voice spectrum — animated bars painted with the spectrum ramp. `level` (0…1) scales
/// amplitude so it can react to the mic. Honors Reduce Motion (renders a calm static frame).
public struct SpectrumWaveform: View {
    private let level: Double
    private let barCount: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(level: Double = 0.5, barCount: Int = 42) {
        self.level = level
        self.barCount = barCount
    }

    public var body: some View {
        if reduceMotion {
            Canvas { ctx, size in draw(ctx, size, time: 0) }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                Canvas { ctx, size in
                    draw(ctx, size, time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, time t: TimeInterval) {
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: KeyVoiceTokens.Colors.spectrum),
            startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)
        )
        let n = barCount
        let slot = size.width / CGFloat(n)
        let bw = slot * 0.5
        let amp = 0.35 + 0.65 * level
        for i in 0..<n {
            let x = (CGFloat(i) + 0.5) * slot
            let base = (0.5 + 0.5 * sin(Double(i) * 0.5 + t / 0.52)) * (0.4 + 0.6 * sin(Double(i) * 0.13 + t / 0.9))
            let bh = max(3, abs(base) * size.height * 0.72 * amp)
            let rect = CGRect(x: x - bw / 2, y: size.height / 2 - bh / 2, width: bw, height: bh)
            ctx.fill(Path(roundedRect: rect, cornerSize: CGSize(width: bw / 2, height: bw / 2)), with: shading)
        }
    }
}
