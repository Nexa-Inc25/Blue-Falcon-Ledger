import Foundation

/// A single turn in an LLM conversation.
struct LLMMessage: Equatable {
    enum Role: String { case system, user, assistant }
    let role: Role
    let content: String
}

enum LLMError: LocalizedError {
    case missingAPIKey(LLMProvider)
    case unavailable(String)
    case badResponse
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let p):
            return "No API key set for \(p.rawValue). Add one in Settings."
        case .unavailable(let why):
            return why
        case .badResponse:
            return "The model sent back something we couldn't read."
        case .http(let code, let body):
            return "Model request failed (\(code)). \(body)"
        }
    }
}

/// Contract every LLM backend implements. Two jobs in the app — chat and analysis —
/// both funnel through `complete`.
protocol LLMService: Sendable {
    /// Send a system prompt + conversation and get the assistant's reply text.
    func complete(system: String, messages: [LLMMessage]) async throws -> String

    /// Approximate characters of agreement context this model can safely take for CHAT
    /// (retrieval-sized). Cloud models are large; the on-device model overrides it lower.
    var contextCharBudget: Int { get }

    /// Characters of agreement context for ANALYSIS — the high-stakes audit. Large-context
    /// cloud models get a big budget so we can send the WHOLE contract (no missed rules);
    /// the on-device model overrides this low and falls back to retrieval.
    var analysisContextChars: Int { get }
}

extension LLMService {
    /// Cloud-model default for chat retrieval — big enough for the wage-schedule region.
    var contextCharBudget: Int { 30_000 }
    /// Cloud-model default for analysis — fits an entire typical CBA (~50k tokens) well
    /// inside Claude's window, so the audit sees every rule, not just retrieved excerpts.
    var analysisContextChars: Int { 200_000 }
}

/// Resolves the user's chosen provider into a concrete service.
@MainActor
enum LLMRouter {
    static func make(settings: AppSettings = .shared) -> LLMService {
        let provider = settings.llmProvider
        switch provider {
        case .bfcCloud:
            // Use the proxy when configured; otherwise fall back to on-device so the app
            // still works before the backend is deployed.
            if AppConfig.proxyConfigured {
                return ProxyProvider(baseURL: AppConfig.proxyBaseURL, appToken: AppConfig.proxyAppToken)
            }
            return AppleIntelligenceProvider()
        case .appleOnDevice:
            return AppleIntelligenceProvider()
        case .claude:
            return ClaudeProvider(apiKey: settings.apiKey(for: .claude) ?? "")
        case .openai:
            return OpenAIProvider(apiKey: settings.apiKey(for: .openai) ?? "")
        case .grok:
            return GrokProvider(apiKey: settings.apiKey(for: .grok) ?? "")
        }
    }
}

/// Shared helper: clip very long context so we don't blow request limits. Labor
/// agreements can be hundreds of pages — keep the head and tail, note the gap.
enum LLMContext {
    static func clip(_ text: String, maxCharacters: Int = 120_000) -> String {
        guard text.count > maxCharacters else { return text }
        let head = text.prefix(maxCharacters * 3 / 4)
        let tail = text.suffix(maxCharacters / 4)
        return "\(head)\n\n…[middle of document trimmed for length]…\n\n\(tail)"
    }
}
