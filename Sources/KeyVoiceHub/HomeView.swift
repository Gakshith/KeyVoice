import SwiftUI
import AppKit
import KeyVoiceStore

/// Home: dictation history grouped by day, search, and a stats card.
struct HomeView: View {
    let store: Store

    @State private var searchText = ""
    @State private var records: [TranscriptRecord] = []

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            if records.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search dictations", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, _ in reload() }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    reload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsRow
                ForEach(groups, id: \.day) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sectionTitle(for: group.day))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(group.rows) { record in
                                TranscriptRow(record: record,
                                              onCopy: { copy(record) },
                                              onDelete: { delete(record) })
                                if record.id != group.rows.last?.id {
                                    Divider().padding(.leading, 12)
                                }
                            }
                        }
                        .background(cardBackground)
                    }
                }
            }
            .padding(16)
        }
    }

    private var statsRow: some View {
        let s = store.stats()
        return HStack(spacing: 12) {
            StatTile(title: "Total words", value: s.words.formatted(), systemImage: "text.word.spacing")
            StatTile(title: "Day streak", value: "\(s.streak)", systemImage: "flame")
            StatTile(title: "Avg WPM", value: "\(s.avgWPM)", systemImage: "speedometer")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text(searchText.isEmpty ? "No dictations yet" : "No matches")
                .font(.title3.weight(.semibold))
            Text(searchText.isEmpty
                 ? "Hold Right-Option and speak."
                 : "Try a different search.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
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

/// A single stat tile with a large tabular figure.
private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

/// One transcript row: text (2-line truncation) + secondary meta line, with hover actions.
private struct TranscriptRow: View {
    let record: TranscriptRecord
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.text)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if hovering {
                HStack(spacing: 4) {
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
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var metaLine: String {
        let time = record.date.formatted(date: .omitted, time: .shortened)
        let words = "\(record.wordCount) word\(record.wordCount == 1 ? "" : "s")"
        return "\(record.appName) · \(time) · \(words)"
    }
}
