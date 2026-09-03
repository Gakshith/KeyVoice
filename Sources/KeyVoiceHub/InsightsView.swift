import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Insights: local-only usage, computed from your own transcripts. Honest metrics — no invented
/// global percentile. The privacy counter is the anchor: your audio never leaves this Mac.
struct InsightsView: View {
    let store: Store

    @State private var stats: (words: Int, streak: Int, avgWPM: Int) = (0, 0, 0)
    @State private var dictations = 0
    @State private var topApps: [(name: String, count: Int)] = []
    @State private var days: [Date: Int] = [:]

    // Adaptive columns: the stat cards and the two panels wrap to fewer
    // columns (down to one) as the window narrows.
    private let statColumns = [GridItem(.adaptive(minimum: 200), spacing: 16)]
    private let panelColumns = [GridItem(.adaptive(minimum: 320), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LazyVGrid(columns: statColumns, alignment: .leading, spacing: 16) {
                    StudioCard {
                        VStack(alignment: .leading, spacing: 10) {
                            StudioStat(value: "\(stats.avgWPM)", unit: "wpm", label: "Average pace")
                            ArcGauge(fraction: min(Double(stats.avgWPM) / 180.0, 1))
                                .frame(height: 66)
                                .frame(maxWidth: .infinity)
                        }
                    }.frame(maxWidth: .infinity)
                    StudioCard { StudioStat(value: dictations.formatted(), label: "Dictations") }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    StudioCard { StudioStat(value: stats.words.formatted(), label: "Words all time") }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                LazyVGrid(columns: panelColumns, alignment: .leading, spacing: 16) {
                    usageCard.frame(maxWidth: .infinity)
                    heatmapCard.frame(maxWidth: .infinity)
                }

                privacyCounter
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Insights").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("All computed on your Mac. Nothing tracked, nothing uploaded.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private var usageCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("Where you dictate", meta: "\(topApps.count) app\(topApps.count == 1 ? "" : "s")")
                if topApps.isEmpty {
                    Text("No dictations yet.").font(.system(size: 13)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                } else {
                    let maxCount = max(topApps.first?.count ?? 1, 1)
                    ForEach(Array(topApps.enumerated()), id: \.offset) { idx, app in
                        UsageBar(label: app.name,
                                 fraction: Double(app.count) / Double(maxCount),
                                 color: KeyVoiceTokens.Colors.spectrum[idx % KeyVoiceTokens.Colors.spectrum.count],
                                 value: app.count)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var heatmapCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("Activity", meta: "\(stats.streak)-day streak")
                Heatmap(days: days)
                HStack(spacing: 6) {
                    Text("Less").font(.system(size: 11, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                    ForEach(0..<4) { l in
                        RoundedRectangle(cornerRadius: 3).fill(Heatmap.color(forLevel: l))
                            .frame(width: 12, height: 12)
                    }
                    Text("More").font(.system(size: 11, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var privacyCounter: some View {
        StudioCard {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield").font(.system(size: 26)).foregroundStyle(KeyVoiceTokens.Colors.good)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your audio, sent to the cloud")
                        .font(.system(size: 12, weight: .semibold)).tracking(0.4)
                        .foregroundStyle(KeyVoiceTokens.Colors.fog)
                    Text("0 bytes").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.good)
                }
                Spacer()
                Text("Every word is transcribed on-device and never uploaded.")
                    .font(.system(size: 13)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                    .frame(maxWidth: 240, alignment: .trailing).multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func cardTitle(_ title: String, meta: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.studioSerif(22)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Spacer()
            Text(meta.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6)
                .foregroundStyle(KeyVoiceTokens.Colors.fog)
        }
    }

    // MARK: - Data

    private func reload() {
        stats = store.stats()
        let all = store.transcripts()
        dictations = all.count
        topApps = Dictionary(grouping: all, by: { $0.appName })
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5).map { $0 }
        let cal = Calendar.current
        days = Dictionary(grouping: all, by: { cal.startOfDay(for: $0.date) }).mapValues { $0.count }
    }
}

// MARK: - Insights primitives

/// A semicircular gauge filled along the voice spectrum.
private struct ArcGauge: View {
    let fraction: Double
    var body: some View {
        ZStack {
            SemiArc().stroke(KeyVoiceTokens.Colors.paper2, style: StrokeStyle(lineWidth: 13, lineCap: .round))
            SemiArc().trim(from: 0, to: max(0.001, min(fraction, 1)))
                .stroke(KeyVoiceTokens.Colors.spectrumGradient, style: StrokeStyle(lineWidth: 13, lineCap: .round))
        }
    }
}

private struct SemiArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width / 2, rect.height) - 8
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return p
    }
}

/// A labeled usage bar.
private struct UsageBar: View {
    let label: String
    let fraction: Double
    let color: Color
    let value: Int
    var body: some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                .frame(width: 96, alignment: .leading).lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(KeyVoiceTokens.Colors.paper2)
                    Capsule().fill(color)
                        .frame(width: max(18, geo.size.width * fraction))
                }
            }
            .frame(height: 22)
            Text("\(value)").font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(KeyVoiceTokens.Colors.fog).frame(width: 34, alignment: .trailing)
        }
    }
}

/// A GitHub-style activity heatmap: last 18 weeks, colored by daily dictation count.
private struct Heatmap: View {
    let days: [Date: Int]
    private let weeks = 18
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 18)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<(weeks * 7), id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Heatmap.color(forLevel: level(daysAgo: weeks * 7 - 1 - i)))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    private func level(daysAgo: Int) -> Int {
        let cal = Calendar.current
        guard let day = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date())) else { return 0 }
        let count = days[day] ?? 0
        switch count {
        case 0: return 0
        case 1...2: return 1
        case 3...5: return 2
        default: return 3
        }
    }

    static func color(forLevel level: Int) -> Color {
        switch level {
        case 1: return KeyVoiceTokens.Colors.accent.opacity(0.35)
        case 2: return KeyVoiceTokens.Colors.accent.opacity(0.62)
        case 3: return KeyVoiceTokens.Colors.accent
        default: return KeyVoiceTokens.Colors.paper2
        }
    }
}
