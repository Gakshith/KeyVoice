import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Insights: local-only usage, computed from your own transcripts. Honest metrics — no invented
/// global percentile. The privacy counter is the anchor: your audio never leaves this Mac.
struct InsightsView: View {
    let store: Store

    @State private var stats: (words: Int, streak: Int, avgWPM: Int) = (0, 0, 0)
    @State private var dictations = 0
    @State private var bestWPM = 0
    @State private var wordsThisWeek = 0
    @State private var longestStreak = 0
    @State private var topApps: [(name: String, count: Int)] = []
    @State private var days: [Date: Int] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                topStats
                panels
                streakCard
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

    // MARK: - Top stats (equal-height)

    private var topStats: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                wpmCard
                metricCard(value: stats.words.formatted(), label: "Words all time", sub: "\(wordsThisWeek.formatted()) this week")
                metricCard(value: dictations.formatted(), label: "Dictations", sub: "across \(topApps.count) app\(topApps.count == 1 ? "" : "s")")
            }
            VStack(spacing: 16) {
                wpmCard
                HStack(alignment: .top, spacing: 16) {
                    metricCard(value: stats.words.formatted(), label: "Words all time", sub: "\(wordsThisWeek.formatted()) this week")
                    metricCard(value: dictations.formatted(), label: "Dictations", sub: "across \(topApps.count) app\(topApps.count == 1 ? "" : "s")")
                }
            }
        }
    }

    private var wpmCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 12) {
                StudioStat(value: "\(stats.avgWPM)", unit: "wpm", label: "Average pace")
                Spacer(minLength: 6)
                ArcGauge(fraction: min(Double(stats.avgWPM) / 180.0, 1))
                    .frame(height: 58).frame(maxWidth: .infinity)
                Text(bestWPM > 0 ? "Personal best \(bestWPM) wpm" : "Speak to set your pace")
                    .font(.system(size: 11.5, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(KeyVoiceTokens.Colors.fog).frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricCard(value: String, label: String, sub: String) -> some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                StudioStat(value: value, label: label)
                Text(sub).font(.system(size: 12)).foregroundStyle(KeyVoiceTokens.Colors.fog).padding(.top, 6)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Panels

    private var panels: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                usageCard.frame(maxWidth: .infinity)
                highlightsCard.frame(width: 260)
            }
            VStack(spacing: 16) {
                usageCard.frame(maxWidth: .infinity)
                highlightsCard.frame(maxWidth: .infinity)
            }
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

    private var highlightsCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 0) {
                cardTitle("Highlights", meta: "")
                highlightRow("bolt.fill", "\(bestWPM)", "best pace (wpm)")
                divider
                highlightRow("calendar", "\(wordsThisWeek.formatted())", "words this week")
                divider
                highlightRow("flame.fill", "\(longestStreak)", "longest streak (days)")
                divider
                highlightRow("app.badge", "\(topApps.count)", "apps used")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var divider: some View { Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1).padding(.vertical, 10) }

    private func highlightRow(_ icon: String, _ value: String, _ label: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(KeyVoiceTokens.Colors.accent).frame(width: 18)
            Text(value).font(.studioSerif(20)).monospacedDigit().foregroundStyle(KeyVoiceTokens.Colors.text)
            Text(label).font(.system(size: 12.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Streak calendar (the centerpiece)

    private var streakCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(stats.streak) day streak").font(.studioSerif(24)).foregroundStyle(KeyVoiceTokens.Colors.text)
                    Spacer()
                    Text("LONGEST · \(longestStreak) DAY\(longestStreak == 1 ? "" : "S")")
                        .font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(KeyVoiceTokens.Colors.fog)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    StreakCalendar(days: days)
                }
                HStack(spacing: 6) {
                    Text("Less").font(.system(size: 11, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                    ForEach(0..<4) { l in
                        RoundedRectangle(cornerRadius: 3).fill(StreakCalendar.color(forLevel: l)).frame(width: 12, height: 12)
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
                        .font(.system(size: 12, weight: .semibold)).tracking(0.4).foregroundStyle(KeyVoiceTokens.Colors.fog)
                    Text("0 bytes").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.good)
                }
                Spacer()
                Text("Your voice is transcribed on-device and never leaves this Mac.")
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
            if !meta.isEmpty {
                Text(meta.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(KeyVoiceTokens.Colors.fog)
            }
        }
    }

    // MARK: - Data

    private func reload() {
        stats = store.stats()
        let all = store.transcripts()
        dictations = all.count
        bestWPM = all.map(\.wpm).max() ?? 0
        let cal = Calendar.current
        let weekAgo = cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        wordsThisWeek = all.filter { $0.date >= weekAgo }.reduce(0) { $0 + $1.wordCount }
        topApps = Dictionary(grouping: all, by: { $0.appName })
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5).map { $0 }
        let dayCounts = Dictionary(grouping: all, by: { cal.startOfDay(for: $0.date) }).mapValues { $0.count }
        days = dayCounts
        longestStreak = Self.longestRun(of: Set(dayCounts.keys))
    }

    /// Longest run of consecutive calendar days present in the set.
    private static func longestRun(of days: Set<Date>) -> Int {
        guard !days.isEmpty else { return 0 }
        let cal = Calendar.current
        var best = 0
        for day in days {
            // Only start counting at the beginning of a run (no previous day present).
            if days.contains(cal.date(byAdding: .day, value: -1, to: day)!) { continue }
            var length = 1
            var next = cal.date(byAdding: .day, value: 1, to: day)!
            while days.contains(next) { length += 1; next = cal.date(byAdding: .day, value: 1, to: next)! }
            best = max(best, length)
        }
        return best
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
                    Capsule().fill(color).frame(width: max(18, geo.size.width * fraction))
                }
            }
            .frame(height: 22)
            Text("\(value)").font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(KeyVoiceTokens.Colors.fog).frame(width: 34, alignment: .trailing)
        }
    }
}

/// A GitHub/Wispr-style activity calendar: weekday rows × week columns, month labels on top, colored
/// by daily dictation count. Last ~20 weeks.
private struct StreakCalendar: View {
    let days: [Date: Int]
    private let weeks = 20
    private let cell: CGFloat = 13
    private let gap: CGFloat = 3
    private static let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private let cal = Calendar.current
    private var startDate: Date {
        let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? cal.startOfDay(for: Date())
        return cal.date(byAdding: .day, value: -7 * (weeks - 1), to: thisWeekStart) ?? thisWeekStart
    }

    private func date(week: Int, weekday: Int) -> Date {
        cal.date(byAdding: .day, value: week * 7 + weekday, to: startDate) ?? startDate
    }

    /// Month markers: (week index, short month name) at every column where the month changes.
    private var monthMarkers: [(week: Int, name: String)] {
        var out: [(Int, String)] = []
        var lastMonth = -1
        for w in 0..<weeks {
            let m = cal.component(.month, from: date(week: w, weekday: 0))
            if m != lastMonth {
                out.append((w, cal.shortMonthSymbols[m - 1]))
                lastMonth = m
            }
        }
        return out.map { (week: $0.0, name: $0.1) }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Weekday labels, aligned under the month-label row.
            VStack(alignment: .leading, spacing: gap) {
                Color.clear.frame(height: 14)
                ForEach(Self.weekdayLabels, id: \.self) { d in
                    Text(d).font(.system(size: 9, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.fog)
                        .frame(height: cell, alignment: .center)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                // Month labels overlaid so they never shift the columns.
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(height: 14)
                    ForEach(monthMarkers, id: \.week) { m in
                        Text(m.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                            .fixedSize().offset(x: CGFloat(m.week) * (cell + gap))
                    }
                }
                // 7 weekday rows × N week columns.
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { d in
                        HStack(spacing: gap) {
                            ForEach(0..<weeks, id: \.self) { w in
                                let day = date(week: w, weekday: d)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(day > Date() ? Color.clear : Self.color(forLevel: Self.level(count: days[cal.startOfDay(for: day)] ?? 0)))
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
            }
        }
    }

    private static func level(count: Int) -> Int {
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
