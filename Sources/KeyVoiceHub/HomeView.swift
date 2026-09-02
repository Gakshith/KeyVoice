import SwiftUI
import AppKit
import KeyVoiceDesign
import KeyVoiceStore

/// Home: dictation history grouped by day, search, and a stats card.
struct HomeView: View {
    let store: Store

    @State private var searchText = ""
    @State private var records: [TranscriptRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            searchField
            if records.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KeyVoiceTokens.Colors.ink.opacity(0.025))
        .navigationTitle("Home")
        .onAppear(perform: reload)
    }

    // MARK: - Data

    private func reload() {
        records = store.transcripts(matching: searchText)
    }

    /// History grouped into (day, rows), newest day first, rows newest first within a day.
    private var groups: [(day: Date, rows: [TranscriptRecord])] {
        let cal = Calendar.current
        let buckets = Dictionary(grouping: records) { cal.startOfDay(for: $0.date) }
        return buckets
            .map { (day: $0.key, rows: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: KeyVoiceTokens.Spacing.s) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KeyVoiceTokens.Colors.ice)
            TextField("Search dictations", text: $searchText)
                .textFieldStyle(.plain)
                .font(KeyVoiceTokens.Typography.body)
                .foregroundStyle(KeyVoiceTokens.Colors.ink)
                .tint(KeyVoiceTokens.Colors.ice)
                .onChange(of: searchText) { _, _ in reload() }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    reload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, KeyVoiceTokens.Spacing.m)
        .padding(.vertical, KeyVoiceTokens.Spacing.s)
        .glassSurface(shape: Capsule())
        .padding(.horizontal, KeyVoiceTokens.Spacing.l)
        .padding(.top, KeyVoiceTokens.Spacing.l)
        .padding(.bottom, KeyVoiceTokens.Spacing.m)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.l) {
                statsRow
                ForEach(groups, id: \.day) { group in
                    VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.s) {
                        SectionHeader(sectionTitle(for: group.day))
                            .padding(.horizontal, KeyVoiceTokens.Spacing.xs)
                        VStack(spacing: 0) {
                            ForEach(group.rows) { record in
                                TranscriptRow(record: record,
                                              onCopy: { copy(record) },
                                              onDelete: { delete(record) })
                                if record.id != group.rows.last?.id {
                                    Divider()
                                        .overlay(KeyVoiceTokens.Colors.ice.opacity(0.18))
                                        .padding(.horizontal, KeyVoiceTokens.Spacing.l)
                                }
                            }
                        }
                        .glassSurface()
                    }
                }
            }
            .padding(.horizontal, KeyVoiceTokens.Spacing.l)
            .padding(.bottom, KeyVoiceTokens.Spacing.l)
        }
    }

    private var statsRow: some View {
        let s = store.stats()
        return HStack(spacing: KeyVoiceTokens.Spacing.m) {
            StatTile(title: "Total words", value: s.words.formatted())
            StatTile(title: "Day streak", value: "\(s.streak)")
            StatTile(title: "Avg WPM", value: "\(s.avgWPM)")
        }
    }

    private var emptyState: some View {
        VStack {
            GlassCard {
                VStack(spacing: KeyVoiceTokens.Spacing.m) {
                    Image(systemName: "waveform")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(KeyVoiceTokens.Colors.ice)
                    Text(searchText.isEmpty ? "No dictations yet" : "No matches")
                        .font(KeyVoiceTokens.Typography.headline)
                        .foregroundStyle(KeyVoiceTokens.Colors.ink)
                    Text(searchText.isEmpty
                         ? "Hold Right-Option and speak."
                         : "Try a different search.")
                        .font(KeyVoiceTokens.Typography.body)
                        .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.62))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 380)
        }
        .padding(KeyVoiceTokens.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func copy(_ record: TranscriptRecord) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(record.text, forType: .string)
    }

    private func delete(_ record: TranscriptRecord) {
        store.delete(record)
        reload()
    }

    // MARK: - Formatting

    private func sectionTitle(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

/// One transcript row: text (2-line truncation) + secondary meta line, with hover actions.
private struct TranscriptRow: View {
    let record: TranscriptRecord
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: KeyVoiceTokens.Spacing.m) {
            VStack(alignment: .leading, spacing: KeyVoiceTokens.Spacing.xs) {
                Text(record.text)
                    .font(KeyVoiceTokens.Typography.body)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metaLine)
                    .font(KeyVoiceTokens.Typography.caption)
                    .foregroundStyle(KeyVoiceTokens.Colors.ink.opacity(0.58))
            }
            Spacer(minLength: KeyVoiceTokens.Spacing.s)
            if hovering {
                HStack(spacing: KeyVoiceTokens.Spacing.xs) {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                    }
                    .help("Copy")
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .help("Delete")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(KeyVoiceTokens.Colors.ice)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .padding(.horizontal, KeyVoiceTokens.Spacing.l)
        .padding(.vertical, KeyVoiceTokens.Spacing.m)
        .contentShape(Rectangle())
        .onHover { isHovering in
            withAnimation(KeyVoiceTokens.Motion.quick) {
                hovering = isHovering
            }
        }
    }

    private var metaLine: String {
        let time = record.date.formatted(date: .omitted, time: .shortened)
        let words = "\(record.wordCount) word\(record.wordCount == 1 ? "" : "s")"
        return "\(record.appName) · \(time) · \(words)"
    }
}
