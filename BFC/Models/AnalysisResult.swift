import Foundation
import SwiftData

/// The LLM's verdict on a pay period: did the pay match the labor agreement?
@Model
final class AnalysisResult {
    var verdictRaw: String
    /// One-line headline shown on the card, e.g. "Shorted 4 hrs double time — ~$184".
    var headline: String
    /// Full plain-language breakdown the lineman reads.
    var detail: String
    /// Estimated money owed, if the analysis found a shortfall.
    var amountOwed: Decimal?
    var createdAt: Date

    var payPeriod: PayPeriod?

    var verdict: AnalysisVerdict {
        get { AnalysisVerdict(rawValue: verdictRaw) ?? .needsInfo }
        set { verdictRaw = newValue.rawValue }
    }

    init(
        verdict: AnalysisVerdict,
        headline: String,
        detail: String,
        amountOwed: Decimal? = nil,
        createdAt: Date = .now
    ) {
        self.verdictRaw = verdict.rawValue
        self.headline = headline
        self.detail = detail
        self.amountOwed = amountOwed
        self.createdAt = createdAt
    }
}
