import Foundation

/// Talks to the BFC Cloud proxy instead of an LLM API directly. The proxy holds the
/// Anthropic key server-side, so testers need zero setup. Same request shape as the
/// other providers; the proxy forwards to Claude and returns the text.
struct ProxyProvider: LLMService {
    let baseURL: String
    let appToken: String

    /// Claude sits behind the proxy, so it has a large context window.
    var contextCharBudget: Int { 30_000 }

    func complete(system: String, messages: [LLMMessage]) async throws -> String {
        guard AppConfig.proxyConfigured, let url = URL(string: baseURL + "/v1/chat") else {
            throw LLMError.unavailable("BFC Cloud isn't set up yet. Add your proxy URL in AppConfig, or pick another model in Settings.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !appToken.isEmpty {
            request.setValue("Bearer \(appToken)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "system": system,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            throw LLMError.http(http.statusCode, detail ?? String(data: data, encoding: .utf8)?.prefix(200).description ?? "")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String, !text.isEmpty else {
            throw LLMError.badResponse
        }
        return text
    }
}
