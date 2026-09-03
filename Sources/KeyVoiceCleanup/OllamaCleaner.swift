import Foundation
import os
import KeyVoiceCore

/// Sends transcripts to a locally running Ollama model for cleanup.
/// Returns nil on any failure/timeout so the caller uses the raw transcript.
public final class OllamaCleaner: Cleaner {
    private let model: String
    private let session: URLSession
    private let log = Logger(subsystem: "com.keyvoice.app", category: "cleanup")

    private static let chatEndpoint = URL(string: "http://localhost:11434/api/chat")!
    private static let tagsEndpoint = URL(string: "http://localhost:11434/api/tags")!
    private static let requestTimeout: TimeInterval = 8

    public init(model: String) {
        self.model = model
        self.session = URLSession(configuration: .ephemeral)
    }

    public func clean(_ text: String, app: AppContext) async -> String? {
        guard let request = makeRequest(text: text, app: app) else {
            log.error("Ollama cleanup skipped: failed to encode request body")
            return nil
        }

        // One attempt, plus one retry on a transient failure.
        if let cleaned = await attempt(request) {
            return cleaned
        }
        return await attempt(request)
    }

    /// Returns locally installed model names, or an empty array when Ollama is unavailable.
    public static func detectModels() async -> [String] {
        var request = URLRequest(url: tagsEndpoint)
        request.timeoutInterval = requestTimeout

        do {
            let session = URLSession(configuration: .ephemeral)
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                return []
            }

            return models.compactMap { $0["name"] as? String }
        } catch {
            return []
        }
    }

    private func attempt(_ request: URLRequest) async -> String? {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                log.error("Ollama cleanup failed: non-HTTP response")
                return nil
            }

            guard (200..<300).contains(http.statusCode) else {
                log.error("Ollama cleanup failed: HTTP \(http.statusCode, privacy: .public)")
                return nil
            }

            return parse(data)
        } catch let error as URLError {
            log.error("Ollama cleanup failed: URLError \(error.code.rawValue, privacy: .public)")
            return nil
        } catch {
            log.error("Ollama cleanup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func makeRequest(text: String, app: AppContext) -> URLRequest? {
        let userContent = "App: \(app.appName) (\(app.bundleId))\n\nTranscript:\n\(text)"
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "options": ["temperature": 0.2],
            "messages": [
                ["role": "system", "content": CleanupPrompt.system],
                ["role": "user", "content": userContent],
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            return nil
        }

        var request = URLRequest(url: Self.chatEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = data
        return request
    }

    private func parse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log.error("Ollama cleanup failed: response not JSON")
            return nil
        }

        guard let message = json["message"] as? [String: Any],
              let raw = message["content"] as? String else {
            log.error("Ollama cleanup failed: no message content")
            return nil
        }

        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
