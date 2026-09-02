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
