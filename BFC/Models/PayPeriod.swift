import Foundation
import SwiftData

/// A pay period to be checked against the labor agreement. Groups the days worked and
/// any uploaded stubs, and holds the LLM's analysis verdict.
@Model
final class PayPeriod {
    var startDate: Date
    var endDate: Date
    /// What the lineman was actually paid this period (from the stub), if known.
    var totalPayReceived: Decimal?
    /// Extra context / correction the lineman typed to refine the analysis. Fed to the
    /// model as authoritative info on re-run. Defaulted for clean migration.
    var correctionNote: String = ""
    var createdAt: Date

    var employer: Employer?

    @Relationship(inverse: \WorkDay.payPeriod)
    var workDays: [WorkDay] = []

    @Relationship(deleteRule: .cascade, inverse: \PayDocument.payPeriod)
    var payStubs: [PayDocument] = []

    @Relationship(deleteRule: .cascade, inverse: \AnalysisResult.payPeriod)
    var analysisResult: AnalysisResult?

    var totalHours: Double { workDays.reduce(0) { $0 + $1.totalHours } }
    var straightHours: Double { workDays.reduce(0) { $0 + $1.straightHours } }
    var overtimeHours: Double { workDays.reduce(0) { $0 + $1.overtimeHours } }
    var doubleHours: Double { workDays.reduce(0) { $0 + $1.doubleHours } }
    var perDiemDays: Int { workDays.filter { $0.perDiemReceived }.count }
    var mealsMissed: Int { workDays.reduce(0) { $0 + $1.mealsMissed } }

    init(
        startDate: Date,
        endDate: Date,
        totalPayReceived: Decimal? = nil,
        createdAt: Date = .now
    ) {
        self.startDate = startDate
        self.endDate = endDate
        self.totalPayReceived = totalPayReceived
        self.createdAt = createdAt
    }
}
