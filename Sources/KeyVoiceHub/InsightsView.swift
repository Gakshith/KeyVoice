import SwiftUI
import KeyVoiceDesign
import KeyVoiceStore

/// Insights: local-only usage, computed from your own transcripts. Honest metrics — no invented
/// global percentile. The privacy counter is the anchor: your audio never leaves this Mac.
struct InsightsView: View {
    let store: Store

    @Environment(\.scenePhase) private var scenePhase

    @State private var stats: (words: Int, streak: Int, avgWPM: Int) = (0, 0, 0)
    @State private var dictations = 0
    @State private var bestWPM = 0
    @State private var wordsThisWeek = 0
    @State private var longestStreak = 0
    @State private var topApps: [(name: String, count: Int)] = []
    @State private var dayInfo: [Date: DayInfo] = [:]

    private enum Layout {
        static let maxContentWidth: CGFloat = 1_120
        static let gap: CGFloat = 16
        static let sectionGap: CGFloat = 20
        static let wideBreakpoint: CGFloat = 860
        static let panelBreakpoint: CGFloat = 780
        static let mediumBreakpoint: CGFloat = 620
    }

    var body: some View {
        GeometryReader { proxy in
            let outerPadding: CGFloat = proxy.size.width < 640 ? 20 : (proxy.size.width < 960 ? 24 : 32)
            let contentWidth = min(max(proxy.size.width - outerPadding * 2, 0), Layout.maxContentWidth)

            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionGap) {
                    header
                        .padding(.bottom, 4)
                    topStats(width: contentWidth)
                    panels(width: contentWidth)
                    streakCard
                    privacyCounter
                }
                .frame(width: contentWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Insights").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("Computed locally from your dictation history.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    // MARK: - Top stats (equal-height)

    @ViewBuilder
    private func topStats(width: CGFloat) -> some View {
        if width >= Layout.wideBreakpoint {
            let unit = (width - Layout.gap * 2) / 3.25
            HStack(spacing: Layout.gap) {
                wpmCard.frame(width: unit * 1.25)
                wordsCard.frame(width: unit)
                dictationsCard.frame(width: unit)
            }
            .frame(height: 224)
        } else if width >= Layout.mediumBreakpoint {
            let wpmWidth = (width - Layout.gap) * 0.52
            HStack(spacing: Layout.gap) {
                wpmCard
                    .frame(width: wpmWidth, height: 264)
                VStack(spacing: Layout.gap) {
                    wordsCard.frame(height: 124)
                    dictationsCard.frame(height: 124)
                }
                .frame(width: width - wpmWidth - Layout.gap)
            }
        } else {
            VStack(spacing: Layout.gap) {
                wpmCard.frame(height: 224)
                HStack(spacing: Layout.gap) {
                    wordsCard.frame(maxWidth: .infinity)
                    dictationsCard.frame(maxWidth: .infinity)
                }
                .frame(height: 124)
            }
        }
    }

    private var wordsCard: some View {
        metricCard(value: stats.words.formatted(), label: "Words all time",
                   sub: "\(wordsThisWeek.formatted()) this week")
    }

    private var dictationsCard: some View {
        metricCard(value: dictations.formatted(), label: "Dictations",
                   sub: "across \(topApps.count) app\(topApps.count == 1 ? "" : "s")")
    }

    private var wpmCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 12) {
                InsightStat(value: "\(stats.avgWPM)", unit: "wpm", label: "Average pace")
                Spacer(minLength: 6)
                ArcGauge(fraction: min(Double(stats.avgWPM) / 180.0, 1))
                    .frame(height: 64).frame(maxWidth: .infinity)
                Text(bestWPM > 0 ? "Personal best \(bestWPM) wpm" : "Speak to set your pace")
                    .font(.system(size: 11.5, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(KeyVoiceTokens.Colors.text2).frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricCard(value: String, label: String, sub: String) -> some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                InsightStat(value: value, label: label)
                Text(sub).font(.system(size: 12)).foregroundStyle(KeyVoiceTokens.Colors.text2).padding(.top, 6)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Panels

    @ViewBuilder
    private func panels(width: CGFloat) -> some View {
        if width >= Layout.panelBreakpoint {
            let highlightsWidth = min(320, width * 0.36)
            HStack(spacing: Layout.gap) {
                usageCard
                    .frame(width: width - highlightsWidth - Layout.gap, height: 272)
                highlightsCard
                    .frame(width: highlightsWidth, height: 272)
            }
        } else {
            VStack(spacing: Layout.gap) {
                usageCard.frame(height: 272)
                highlightsCard.frame(height: 272)
            }
        }
    }

    private var usageCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("Where you dictate", meta: "\(topApps.count) app\(topApps.count == 1 ? "" : "s")")
                if topApps.isEmpty {
                    Text("No dictations yet.").font(.system(size: 13)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                } else {
                    let maxCount = max(topApps.first?.count ?? 1, 1)
                    ForEach(Array(topApps.enumerated()), id: \.offset) { idx, app in
                        UsageBar(label: app.name,
                                 fraction: Double(app.count) / Double(maxCount),
                                 color: KeyVoiceTokens.Colors.accent.opacity(max(0.50, 1.0 - Double(idx) * 0.12)),
                                 value: app.count)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var highlightsCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("Highlights", meta: "")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    highlightMetric("bolt.fill", value: "\(bestWPM)", unit: "wpm", label: "Best pace")
                    highlightMetric("calendar", value: wordsThisWeek.formatted(), unit: "words", label: "This week")
                    highlightMetric("flame.fill", value: "\(longestStreak)", unit: "days", label: "Longest streak")
                    highlightMetric("app.badge", value: "\(topApps.count)", unit: "apps", label: "Apps used")
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func highlightMetric(_ icon: String, value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                    .frame(width: 24, height: 24)
                    .background(KeyVoiceTokens.Colors.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(KeyVoiceTokens.Colors.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.studioSerif(22))
                    .monospacedDigit()
                    .foregroundStyle(KeyVoiceTokens.Colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(unit)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(KeyVoiceTokens.Colors.fog)
                    .lineLimit(1)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(KeyVoiceTokens.Colors.card2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(KeyVoiceTokens.Colors.line.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value) \(unit)")
    }

    // MARK: - Streak calendar (the centerpiece)

    private var streakCard: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(stats.streak) day streak").font(.studioSerif(24)).foregroundStyle(KeyVoiceTokens.Colors.text)
                    Spacer()
                    Text("LONGEST · \(longestStreak) DAY\(longestStreak == 1 ? "" : "S")")
                        .font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(KeyVoiceTokens.Colors.text2)
                }
                GeometryReader { geo in
                    StreakCalendar(dayInfo: dayInfo, availableWidth: geo.size.width)
                }
                .frame(height: StreakCalendar.height)
                HStack(spacing: 6) {
                    Text("Less").font(.system(size: 11, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                    ForEach(0..<4) { l in
                        RoundedRectangle(cornerRadius: 3).fill(StreakCalendar.color(forLevel: l)).frame(width: 12, height: 12)
                    }
                    Text("More").font(.system(size: 11, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var privacyCounter: some View {
        StudioCard(padding: 20) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    privacyIcon
                    privacyMessage
                    Spacer(minLength: 20)
                    Text("Cloud cleanup may send transcript text to the provider you choose.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(KeyVoiceTokens.Colors.text2)
                        .frame(maxWidth: 330, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        privacyIcon
                        privacyMessage
                    }
                    Text("Cloud cleanup may send transcript text to the provider you choose.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(KeyVoiceTokens.Colors.text2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var privacyIcon: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: 21, weight: .semibold))
            .foregroundStyle(KeyVoiceTokens.Colors.accent)
            .frame(width: 42, height: 42)
            .background(KeyVoiceTokens.Colors.accentSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityHidden(true)
    }

    private var privacyMessage: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Audio stays on this Mac")
                .font(.studioSerif(19))
                .foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("Transcription and these insights are computed on-device.")
                .font(.system(size: 12.5))
                .foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private func cardTitle(_ title: String, meta: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.studioSerif(22)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Spacer()
            if !meta.isEmpty {
                Text(meta.uppercased()).font(.system(size: 11, weight: .bold)).tracking(0.6).foregroundStyle(KeyVoiceTokens.Colors.text2)
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
        let byDay = Dictionary(grouping: all, by: { cal.startOfDay(for: $0.date) })
        dayInfo = byDay.mapValues { items in
            let topApp = Dictionary(grouping: items, by: { $0.appName })
                .max { $0.value.count < $1.value.count }?.key ?? "—"
            return DayInfo(count: items.count,
                           words: items.reduce(0) { $0 + $1.wordCount },
                           apps: Set(items.map { $0.appName }).count,
                           topApp: topApp)
        }
        longestStreak = Self.longestRun(of: Set(byDay.keys))
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

/// Insights uses a darker secondary tone than the shared stat so small labels clear WCAG contrast.
private struct InsightStat: View {
    let value: String
    var unit: String?
    let label: String

    init(value: String, unit: String? = nil, label: String) {
        self.value = value
        self.unit = unit
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(value)
                    .font(.studioSerif(36))
                    .monospacedDigit()
                    .foregroundStyle(KeyVoiceTokens.Colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if let unit {
                    Text(unit)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KeyVoiceTokens.Colors.text2)
                }
            }
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(KeyVoiceTokens.Colors.text2)
                .lineLimit(1)
        }
    }
}

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
                .frame(width: 112, alignment: .leading).lineLimit(1)
                .help(label)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(KeyVoiceTokens.Colors.paper2)
                    Capsule().fill(color).frame(width: max(18, geo.size.width * fraction))
                }
            }
            .frame(height: 22)
            Text("\(value)").font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                .foregroundStyle(KeyVoiceTokens.Colors.text2).frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) dictation\(value == 1 ? "" : "s")")
    }
}

/// A GitHub/Wispr-style activity calendar: weekday rows × week columns, month labels on top, colored
/// by daily dictation count. The column count adapts to the available width so the grid always fills
/// its card. Click any past day for a detail popover.
private struct StreakCalendar: View {
    let dayInfo: [Date: DayInfo]
    /// Width offered by the parent; the number of week columns is derived from it.
    let availableWidth: CGFloat

    private let cell: CGFloat = 14
    private let gap: CGFloat = 10
    private let labelColumn: CGFloat = 30           // weekday labels + the HStack spacing
    private let labelRow: CGFloat = 14              // month-label strip above the grid
    private static let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    /// Fixed height of the whole calendar — lets the GeometryReader parent reserve exact space.
    static let height: CGFloat = 14 /* label row */ + 7 * 24 /* accessible hit target */

    @State private var selected: Date?
    private let cal = Calendar.current

    /// Columns that fit the available width, clamped to a sane range (a few weeks … one year).
    private var weeks: Int {
        let usable = max(0, availableWidth - labelColumn)
        let fit = Int(floor(usable / (cell + gap)))
        return min(53, max(12, fit))
    }

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
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: labelRow)
                ForEach(Self.weekdayLabels, id: \.self) { d in
                    Text(d).font(.system(size: 9, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                        .frame(width: 22, height: cell + gap, alignment: .leading)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                // Month labels overlaid so they never shift the columns.
                ZStack(alignment: .topLeading) {
                    Color.clear.frame(height: labelRow)
                    ForEach(monthMarkers, id: \.week) { m in
                        Text(m.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(KeyVoiceTokens.Colors.text2)
                            .fixedSize().offset(x: CGFloat(m.week) * (cell + gap))
                    }
                }
                // 7 weekday rows × N week columns.
                VStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { d in
                        HStack(spacing: 0) {
                            ForEach(0..<weeks, id: \.self) { w in
                                cellView(week: w, weekday: d)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func cellView(week: Int, weekday: Int) -> some View {
        let day = cal.startOfDay(for: date(week: week, weekday: weekday))
        let isFuture = day > Date()
        let info = dayInfo[day]
        let count = info?.count ?? 0
        if isFuture || count == 0 {
            RoundedRectangle(cornerRadius: 3)
                .fill(isFuture ? Color.clear : Self.color(forLevel: Self.level(count: count)))
                .frame(width: cell, height: cell)
                .frame(width: cell + gap, height: cell + gap)
                .accessibilityHidden(true)
        } else {
            Button {
                selected = day
            } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Self.color(forLevel: Self.level(count: count)))
                    .frame(width: cell, height: cell)
                    .overlay {
                        if selected == day {
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(KeyVoiceTokens.Colors.text, lineWidth: 1.5)
                        }
                    }
            }
            .frame(width: cell + gap, height: cell + gap)
            .buttonStyle(.plain)
            .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
            .accessibilityValue("\(count) dictation\(count == 1 ? "" : "s"), \(info?.words ?? 0) words")
            .help("\(count) dictation\(count == 1 ? "" : "s")")
            .popover(isPresented: Binding(get: { selected == day },
                                          set: { if !$0 { selected = nil } }),
                     arrowEdge: .top) {
                DayDetailCard(day: day, info: info)
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

/// One day's locally-computed activity — every field traces to real transcripts, nothing invented.
private struct DayInfo {
    let count: Int
    let words: Int
    let apps: Int
    let topApp: String
}

/// The detail popover shown when a calendar day is clicked.
private struct DayDetailCard: View {
    let day: Date
    let info: DayInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(day.formatted(.dateTime.weekday(.wide)))
                        .font(.studioSerif(18))
                        .foregroundStyle(KeyVoiceTokens.Colors.text)
                    Text(day.formatted(.dateTime.month(.wide).day()))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(KeyVoiceTokens.Colors.text2)
                }
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                    .frame(width: 30, height: 30)
                    .background(KeyVoiceTokens.Colors.accentSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }

            if let info, info.count > 0 {
                HStack(spacing: 0) {
                    dayMetric("Dictations", "\(info.count)")
                    dayMetric("Words", info.words.formatted())
                    dayMetric("Apps", "\(info.apps)")
                }
                .padding(.vertical, 11)
                .background(KeyVoiceTokens.Colors.card2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(KeyVoiceTokens.Colors.line.opacity(0.8), lineWidth: 1)
                }

                HStack(spacing: 8) {
                    Image(systemName: "app.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(KeyVoiceTokens.Colors.accent)
                    Text("Top app")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(KeyVoiceTokens.Colors.text2)
                    Spacer(minLength: 8)
                    Text(info.topApp)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(KeyVoiceTokens.Colors.text)
                        .lineLimit(1)
                }
            } else {
                Label("No dictations this day", systemImage: "waveform")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(KeyVoiceTokens.Colors.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(KeyVoiceTokens.Colors.card2, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            }
        }
        .padding(18)
        .frame(width: 250, alignment: .leading)
        .background(KeyVoiceTokens.Colors.card)
        .presentationBackground(KeyVoiceTokens.Colors.card)
        .environment(\.colorScheme, .light)
    }

    private func dayMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.studioSerif(18))
                .monospacedDigit()
                .foregroundStyle(KeyVoiceTokens.Colors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.35)
                .foregroundStyle(KeyVoiceTokens.Colors.fog)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}
