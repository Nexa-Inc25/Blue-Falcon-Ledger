import Foundation

/// OpenAI Chat Completions API.
struct OpenAIProvider: LLMService {
    let apiKey: String
    var model = "gpt-4o"

    func complete(system: String, messages: [LLMMessage]) async throws -> String {
        guard !apiKey.isEmpty else { throw LLMError.missingAPIKey(.openai) }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var payload: [[String: String]] = [["role": "system", "content": system]]
        payload += messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = ["model": model, "messages": payload]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try ClaudeProvider.checkStatus(response, data)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw LLMError.badResponse
        }
        return text
    }
}
