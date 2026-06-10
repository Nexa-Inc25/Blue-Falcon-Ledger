import Foundation

/// Anthropic Claude via the Messages API. Default cloud provider.
struct ClaudeProvider: LLMService {
    let apiKey: String
    var model = "claude-opus-4-8"
    var maxTokens = 2048

    func complete(system: String, messages: [LLMMessage]) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey(.claude) }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Anthropic takes a top-level system string and user/assistant turns only.
        let turns = messages.filter { $0.role != .system }.map {
            ["role": $0.role == .assistant ? "assistant" : "user",
             "content": $0.content]
        }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": turns
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkStatus(response, data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw LLMError.badResponse
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw LLMError.badResponse }
        return text
    }

    static func checkStatus(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(http.statusCode, String(body.prefix(300)))
        }
    }
}
