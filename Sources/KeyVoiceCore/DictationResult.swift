import Foundation

/// A completed dictation, emitted by the Coordinator when text is successfully inserted.
/// The app shell turns this into a stored history record (word count / WPM are derived here so
/// the store stays dumb). Sendable so it can cross into the persistence layer cleanly.
public struct DictationResult: Sendable, Equatable {
    public let text: String
    public let app: AppContext
    /// How long the key was held (for words-per-minute).
    public let duration: TimeInterval
    public let date: Date

    public init(text: String, app: AppContext, duration: TimeInterval, date: Date = Date()) {
        self.text = text
        self.app = app
        self.duration = duration
        self.date = date
    }

    /// Whitespace-separated word count.
    public var wordCount: Int {
        text.split { $0 == " " || $0 == "\n" || $0 == "\t" }.count
    }

    /// Words per minute for this dictation, or 0 if the duration is too small to be meaningful.
    public var wordsPerMinute: Int {
        guard duration > 0.3 else { return 0 }
        return Int((Double(wordCount) / duration) * 60.0)
    }
}
