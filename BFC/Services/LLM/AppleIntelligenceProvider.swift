import Foundation

/// On-device LLM via Apple's Foundation Models (iOS 26+). Private, free, no API key.
/// The `#if canImport` guard keeps the app building on toolchains/SDKs without the
/// framework; at runtime we also check model availability and give a clear message.
#if canImport(FoundationModels)
import FoundationModels

struct AppleIntelligenceProvider: LLMService {
    /// Foundation Models has a small (~4k token) window, so keep retrieved context tight
    /// — leaving room for the instructions and the generated answer.
    var contextCharBudget: Int { 5_000 }
    /// Small window — analysis must use retrieval, not the whole contract.
    var analysisContextChars: Int { 5_000 }

    func complete(system: String, messages: [LLMMessage]) async throws -> String {
        guard #available(iOS 26.0, *) else {
            throw LLMError.unavailable("On-device intelligence needs iOS 26 or later. Pick a cloud model in Settings.")
        }

        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw LLMError.unavailable(Self.describe(reason))
        @unknown default:
            throw LLMError.unavailable("On-device model isn't ready. Pick a cloud model in Settings.")
        }

        // Foundation Models takes instructions + a single prompt. Fold the (already
        // persisted) conversation into one prompt so context carries across turns.
        let session = LanguageModelSession(instructions: system)
        let prompt = Self.flatten(messages)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private static func flatten(_ messages: [LLMMessage]) -> String {
        messages.map { msg in
            switch msg.role {
            case .user: return "Lineman: \(msg.content)"
            case .assistant: return "You: \(msg.content)"
            case .system: return msg.content
            }
        }.joined(separator: "\n\n")
    }

    @available(iOS 26.0, *)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence. Pick a cloud model in Settings."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings, or pick a cloud model."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly or use a cloud model."
        @unknown default:
            return "On-device model unavailable. Pick a cloud model in Settings."
        }
    }
}

#else

/// Fallback when Foundation Models isn't available in the SDK: route users to a cloud model.
struct AppleIntelligenceProvider: LLMService {
    var contextCharBudget: Int { 5_000 }
    var analysisContextChars: Int { 5_000 }

    func complete(system: String, messages: [LLMMessage]) async throws -> String {
        throw LLMError.unavailable("On-device intelligence isn't available in this build. Pick Claude, OpenAI, or Grok in Settings.")
    }
}
#endif
