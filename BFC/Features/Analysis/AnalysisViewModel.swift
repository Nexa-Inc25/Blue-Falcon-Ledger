import Foundation
import SwiftData

/// Runs the pay-period audit through the LLM and persists the verdict.
@MainActor
@Observable
final class AnalysisViewModel {
    var isRunning = false
    var errorMessage: String?
    /// Set when a free user has used up their BFC Cloud allowance — the view shows the paywall.
    var showPaywall = false

    private let payPeriod: PayPeriod
    private let employer: Employer

    init(payPeriod: PayPeriod, employer: Employer) {
        self.payPeriod = payPeriod
        self.employer = employer
    }

    var hasAgreement: Bool { employer.laborAgreement?.fullText.isEmpty == false }

    func analyze(context: ModelContext) async {
        guard hasAgreement else {
            errorMessage = "Upload this employer's labor agreement first — the analysis needs it."
            return
        }

        // Gate metered BFC Cloud usage for free users.
        let provider = AppSettings.shared.llmProvider
        guard SubscriptionService.shared.cloudAllowed(provider: provider) else {
            showPaywall = true
            return
        }

        errorMessage = nil
        isRunning = true
        defer { isRunning = false }

        // Ensure the agreement is chunked so the engine can retrieve pay-relevant sections.
        if let agreement = employer.laborAgreement {
            AgreementChunker.ensureChunked(agreement, context: context)
            SemanticIndex.ensureEmbeddings(for: agreement, context: context)
        }

        let engine = AnalysisEngine(llm: LLMRouter.make())
        do {
            let result = try await engine.analyze(payPeriod: payPeriod, employer: employer)
            // Replace any prior result.
            if let old = payPeriod.analysisResult { context.delete(old) }
            result.payPeriod = payPeriod
            payPeriod.analysisResult = result
            context.insert(result)
            try? context.save()
            SubscriptionService.shared.noteUsage(provider: provider)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
