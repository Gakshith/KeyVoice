import Foundation

public enum BoundaryReplacer {
    /// Applies ordered (from → to) rules to `text`, matching each `from` only at word/phrase
    /// boundaries, case-insensitively, and inserting `to` with its own stored casing.
    /// Rules are applied sequentially in the given order (caller sorts longest-first).
    public static func apply(_ rules: [(from: String, to: String)], to text: String) -> String {
        var result = text

        for rule in rules where !rule.from.isEmpty {
            var pattern = NSRegularExpression.escapedPattern(for: rule.from)

            if let first = rule.from.first, isWordCharacter(first) {
                pattern = "(?<![A-Za-z0-9_])" + pattern
            }
            if let last = rule.from.last, isWordCharacter(last) {
                pattern += "(?![A-Za-z0-9_])"
            }

            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }

            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            let template = NSRegularExpression.escapedTemplate(for: rule.to)
            result = regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: template
            )
        }

        return result
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1,
              let value = character.unicodeScalars.first?.value else {
            return false
        }

        return (65...90).contains(value)
            || (97...122).contains(value)
            || (48...57).contains(value)
            || value == 95
    }
}
