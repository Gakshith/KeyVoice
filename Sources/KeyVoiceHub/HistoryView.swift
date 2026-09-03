import SwiftUI
import AppKit
import KeyVoiceDesign
import KeyVoiceStore

/// History: every dictation on this Mac, searchable, grouped by day.
struct HistoryView: View {
    let store: Store

    @State private var search = ""
    @State private var records: [TranscriptRecord] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchField
                if records.isEmpty {
                    empty
                } else {
                    ForEach(groups, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            StudioSectionLabel(title(for: group.day))
                            StudioCard(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(group.rows) { record in
                                        row(record)
                                        if record.id != group.rows.last?.id {
                                            Rectangle().fill(KeyVoiceTokens.Colors.line).frame(height: 1)
                                                .padding(.horizontal, 18)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: reload)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("History").font(.studioSerif(30)).foregroundStyle(KeyVoiceTokens.Colors.text)
            Text("Every dictation, on this Mac only. Search it, copy it, re-use it.")
                .font(.system(size: 14.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
        }
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").foregroundStyle(KeyVoiceTokens.Colors.fog)
            TextField("Search dictations", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 14.5))
                .foregroundStyle(KeyVoiceTokens.Colors.text)
                .tint(KeyVoiceTokens.Colors.accent)
                .onChange(of: search) { _, _ in reload() }
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(
            Capsule().fill(KeyVoiceTokens.Colors.card)
                .overlay(Capsule().strokeBorder(KeyVoiceTokens.Colors.line, lineWidth: 1))
        )
    }

    private func row(_ record: TranscriptRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(record.text)
                .font(.system(size: 15)).foregroundStyle(KeyVoiceTokens.Colors.text)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Text(meta(record))
                .font(.system(size: 12.5, weight: .medium)).foregroundStyle(KeyVoiceTokens.Colors.fog)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 15)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy") { copy(record) }
            Button("Delete", role: .destructive) { delete(record) }
        }
    }

    private var empty: some View {
        StudioCard {
            VStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 30, weight: .light))
                    .foregroundStyle(KeyVoiceTokens.Colors.accent)
                Text(search.isEmpty ? "No dictations yet" : "No matches")
                    .font(.studioSerif(20)).foregroundStyle(KeyVoiceTokens.Colors.text)
                Text(search.isEmpty ? "Hold Right-Option and speak." : "Try a different search.")
                    .font(.system(size: 13.5)).foregroundStyle(KeyVoiceTokens.Colors.text2)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
        }
    }

    // MARK: - Data

    private func reload() { records = store.transcripts(matching: search) }

    private var groups: [(day: Date, rows: [TranscriptRecord])] {
        let cal = Calendar.current
        return Dictionary(grouping: records) { cal.startOfDay(for: $0.date) }
            .map { (day: $0.key, rows: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private func meta(_ r: TranscriptRecord) -> String {
        let time = r.date.formatted(date: .omitted, time: .shortened)
        return "\(r.appName) · \(time) · \(r.wordCount) word\(r.wordCount == 1 ? "" : "s")"
    }

    private func title(for day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    private func copy(_ r: TranscriptRecord) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(r.text, forType: .string)
    }
    private func delete(_ r: TranscriptRecord) { store.delete(r); reload() }
}
