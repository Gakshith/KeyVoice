import Foundation
import SwiftData

/// One dictation the user completed. Stored locally, per device — never synced (privacy).
@Model
public final class TranscriptRecord {
    public var text: String
    public var appBundleId: String
    public var appName: String
    public var date: Date
    public var wordCount: Int
    public var wpm: Int

    public init(text: String, appBundleId: String, appName: String, date: Date, wordCount: Int, wpm: Int) {
        self.text = text
        self.appBundleId = appBundleId
        self.appName = appName
        self.date = date
        self.wordCount = wordCount
        self.wpm = wpm
    }
}

/// A per-app writing style. When the user dictates into `appBundleId`, cleanup uses `kind` to
/// match the register (formal/casual/code/clean/raw) — via punctuation & phrasing only.
@Model
public final class StyleRule {
    public var appBundleId: String
    public var appName: String
    public var kind: String
    public var date: Date

    public init(appBundleId: String, appName: String, kind: String, date: Date = Date()) {
        self.appBundleId = appBundleId
        self.appName = appName
        self.kind = kind
        self.date = date
    }
}

/// A voice text-expansion: say `trigger`, get `expansion` pasted. Local only.
@Model
public final class Snippet {
    public var trigger: String
    public var expansion: String
    public var date: Date

    public init(trigger: String, expansion: String, date: Date = Date()) {
        self.trigger = trigger
        self.expansion = expansion
        self.date = date
    }
}

/// A custom word or replacement the user teaches KeyVoice, so names/acronyms come out right.
/// `from` empty ⇒ a "known word" (spelling hint only); `from` non-empty ⇒ replace `from` with `to`.
@Model
public final class DictionaryEntry {
    public var from: String
    public var to: String
    public var starred: Bool
    public var date: Date

    public init(from: String, to: String, starred: Bool = false, date: Date = Date()) {
        self.from = from
        self.to = to
        self.starred = starred
        self.date = date
    }
}
