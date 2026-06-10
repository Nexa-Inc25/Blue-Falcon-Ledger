import Foundation
import SwiftData

/// Drives the labor-agreement chat. Persists every message on the agreement so the
/// conversation survives restarts, and routes turns through the configured LLM.
@MainActor
@Observable
final class ChatViewModel {
    var input = ""
    var isSending = false
    var errorMessage: String?
    /// Set when a free user has used up their BFC Cloud allowance — the view shows the paywall.
    var showPaywall = false

    private let employer: Employer
    private let agreement: LaborAgreement

    init?(employer: Employer) {
        guard let agreement = employer.laborAgreement else { return nil }
        self.employer = employer
        self.agreement = agreement
    }

    var canSend: Bool {
        !input.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    /// Messages in chronological order for display.
    func sortedMessages() -> [ChatMessage] {
        agreement.chatMessages.sorted { $0.timestamp < $1.timestamp }
    }

    func send(context: ModelContext) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Gate metered BFC Cloud usage for free users (keep their text so they don't lose it).
        let provider = AppSettings.shared.llmProvider
        guard SubscriptionService.shared.cloudAllowed(provider: provider) else {
            showPaywall = true
            return
        }

        input = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        userMessage.agreement = agreement
        agreement.chatMessages.append(userMessage)
        context.insert(userMessage)
        try? context.save()

        isSending = true
        defer { isSending = false }

        // RAG: make sure the agreement is chunked, then send only the chunks most
        // relevant to THIS question — never the whole contract. Rate/pay questions get
        // broader retrieval (more chunks + wage schedules/appendices boosted in).
        // Cap the context to the active model's window (on-device is small).
        AgreementChunker.ensureChunked(agreement, context: context)
        SemanticIndex.ensureEmbeddings(for: agreement, context: context)
        let llm = LLMRouter.make()
        let budget = llm.contextCharBudget
        let retrieved: ChunkRetriever.Result
        if ChunkRetriever.isRateQuery(text) {
            // Pulls in the whole wage-schedule region so every classification surfaces.
            retrieved = ChunkRetriever.retrieveForRates(query: text, from: agreement.chunks,
                                                        charBudget: budget)
        } else {
            retrieved = ChunkRetriever.retrieve(query: text, from: agreement.chunks,
                                                limit: 8, charBudget: min(14_000, budget))
        }

        let system = AnalysisEngine.chatSystemPrompt(employer: employer,
                                                     excerpts: retrieved.contextText)
        // Keep only recent conversation turns; the agreement context comes from excerpts.
        let history = sortedMessages().suffix(10).map {
            LLMMessage(role: $0.role == .assistant ? .assistant : .user, content: $0.content)
        }

        // De-duplicated section headings used, shown under the answer for verification.
        var seenSource = Set<String>()
        let sources = retrieved.chunks.compactMap { chunk -> String? in
            let base = ChunkRetriever.baseHeading(chunk.heading)
            guard !base.isEmpty, seenSource.insert(base).inserted else { return nil }
            return base
        }

        do {
            let reply = try await llm.complete(system: system, messages: history)
            let assistant = ChatMessage(role: .assistant, content: reply, sources: sources)
            assistant.agreement = agreement
            agreement.chatMessages.append(assistant)
            context.insert(assistant)
            try? context.save()
            SubscriptionService.shared.noteUsage(provider: provider)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
