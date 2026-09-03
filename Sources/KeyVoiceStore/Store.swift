import Foundation
import SwiftData
import KeyVoiceCore

/// The local data store: dictation history + the custom dictionary, backed by SwiftData.
/// Everything stays on this Mac. `@MainActor` because the UI binds to it directly and SwiftData's
/// main context is main-actor bound.
@MainActor
public final class Store {
    public let context: ModelContext
    private let container: ModelContainer

    /// Builds the on-disk store. Falls back to an in-memory store if the disk container can't be
    /// created, so the app still runs (history just won't persist) rather than crashing.
    public init() {
        let schema = Schema([TranscriptRecord.self, DictionaryEntry.self, StyleRule.self, Snippet.self])
        if let disk = try? ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema)) {
            container = disk
        } else {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: memory))
                ?? { fatalError("SwiftData could not create even an in-memory container") }()
            Log.error("history store fell back to in-memory (won't persist)")
        }
        context = container.mainContext
    }

    // MARK: - History

    /// Record a completed dictation. Applies nothing — the text is already final.
    public func record(_ result: DictationResult) {
        let entry = TranscriptRecord(
            text: result.text,
            appBundleId: result.app.bundleId,
            appName: result.app.appName,
            date: result.date,
            wordCount: result.wordCount,
            wpm: result.wordsPerMinute
        )
        context.insert(entry)
        try? context.save()
    }

    /// Recent transcripts, newest first, optionally filtered by a case-insensitive search.
    public func transcripts(matching search: String = "") -> [TranscriptRecord] {
        let all = (try? context.fetch(FetchDescriptor<TranscriptRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
        guard !search.isEmpty else { return all }
        return all.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    public func delete(_ record: TranscriptRecord) {
        context.delete(record)
        try? context.save()
    }

    public func clearHistory() {
        let records = (try? context.fetch(FetchDescriptor<TranscriptRecord>())) ?? []
        for record in records {
            context.delete(record)
        }
        try? context.save()
    }

    /// Aggregate stats for the Home card: total words, current day-streak, average WPM.
    public func stats() -> (words: Int, streak: Int, avgWPM: Int) {
        let all = transcripts()
        let words = all.reduce(0) { $0 + $1.wordCount }
        let wpms = all.map(\.wpm).filter { $0 > 0 }
        let avg = wpms.isEmpty ? 0 : wpms.reduce(0, +) / wpms.count
        return (words, dayStreak(all), avg)
    }

    /// Consecutive days (ending today) with at least one dictation.
    private func dayStreak(_ records: [TranscriptRecord]) -> Int {
        let cal = Calendar.current
        let days = Set(records.map { cal.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var day = cal.startOfDay(for: Date())
        // Allow the streak to start today or yesterday (don't break it before the day is over).
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day)! }
        while days.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    // MARK: - Dictionary

    public func dictionaryEntries() -> [DictionaryEntry] {
        let all = (try? context.fetch(FetchDescriptor<DictionaryEntry>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
        // Starred first, then newest (SwiftData can't sort on a Bool keypath, so order in Swift).
        return all.sorted { a, b in
            a.starred != b.starred ? a.starred : a.date > b.date
        }
    }

    public func addDictionaryEntry(from: String, to: String) {
        context.insert(DictionaryEntry(from: from, to: to))
        try? context.save()
    }

    public func delete(_ entry: DictionaryEntry) {
        context.delete(entry)
        try? context.save()
    }

    // MARK: - Styles

    /// Per-app style rules, newest first.
    public func styleRules() -> [StyleRule] {
        (try? context.fetch(FetchDescriptor<StyleRule>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
    }

    /// The style kind for a bundle id, or nil if the user hasn't set one (caller falls back).
    public func style(forBundleId bundleId: String) -> String? {
        styleRules().first { $0.appBundleId == bundleId }?.kind
    }

    public func addStyleRule(appBundleId: String, appName: String, kind: String) {
        // One rule per app — replace an existing one rather than duplicating.
        for existing in styleRules() where existing.appBundleId == appBundleId {
            context.delete(existing)
        }
        context.insert(StyleRule(appBundleId: appBundleId, appName: appName, kind: kind))
        try? context.save()
    }

    public func delete(_ rule: StyleRule) {
        context.delete(rule)
        try? context.save()
    }

    // MARK: - Snippets

    /// Voice snippets, newest first.
    public func snippets() -> [Snippet] {
        (try? context.fetch(FetchDescriptor<Snippet>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        ))) ?? []
    }

    public func addSnippet(trigger: String, expansion: String) {
        context.insert(Snippet(trigger: trigger, expansion: expansion))
        try? context.save()
    }

    /// Expand snippet triggers found in a transcript (whole-phrase, case-insensitive). Longer
    /// triggers first so "meeting link" wins over "meeting".
    public func expandSnippets(in text: String) -> String {
        var out = text
        for snippet in snippets().sorted(by: { $0.trigger.count > $1.trigger.count })
        where !snippet.trigger.isEmpty {
            out = out.replacingOccurrences(of: snippet.trigger, with: snippet.expansion, options: [.caseInsensitive])
        }
        return out
    }

    public func delete(_ snippet: Snippet) {
        context.delete(snippet)
        try? context.save()
    }

    /// Apply the user's replacements to a transcript (whole-word, case-insensitive). Used as a
    /// post-transcription pass so taught names/acronyms come out right even before Claude cleanup.
    public func applyReplacements(to text: String) -> String {
        var out = text
        for entry in dictionaryEntries() where !entry.from.isEmpty {
            out = out.replacingOccurrences(
                of: entry.from,
                with: entry.to,
                options: [.caseInsensitive]
            )
        }
        return out
    }
}
