import Foundation
import SwiftData

/// A contractor / employer the lineman has worked for. The home screen shows the
/// current employer big at top and the rest as history.
@Model
final class Employer {
    var name: String
    var ibewLocal: String
    /// Per diem paid per day worked. Money is always `Decimal`.
    var perDiemRate: Decimal
    /// Home address used for this job (per-job tax context can differ from profile).
    var homeAddress: String
    var dependents: Int
    var filingStatusRaw: String
    /// The lineman's classification on this job — tells the analysis which wage row to
    /// apply (foreman vs JL, etc.). Defaulted for clean migration.
    var classificationRaw: String = LinemanClassification.journeymanLineman.rawValue
    /// Exactly one employer should be current at a time (enforced in the view model).
    var isCurrent: Bool
    var createdAt: Date

    // The signed labor agreement governing this employer's pay.
    @Relationship(deleteRule: .cascade, inverse: \LaborAgreement.employer)
    var laborAgreement: LaborAgreement?

    @Relationship(deleteRule: .cascade, inverse: \WorkDay.employer)
    var workDays: [WorkDay] = []

    @Relationship(deleteRule: .cascade, inverse: \PayPeriod.employer)
    var payPeriods: [PayPeriod] = []

    @Relationship(deleteRule: .cascade, inverse: \PayDocument.employer)
    var documents: [PayDocument] = []

    var filingStatus: FilingStatus {
        get { FilingStatus(rawValue: filingStatusRaw) ?? .single }
        set { filingStatusRaw = newValue.rawValue }
    }

    var classification: LinemanClassification {
        get { LinemanClassification(rawValue: classificationRaw) ?? .journeymanLineman }
        set { classificationRaw = newValue.rawValue }
    }

    var hasAgreement: Bool { laborAgreement?.fullText.isEmpty == false }

    init(
        name: String,
        ibewLocal: String = "",
        perDiemRate: Decimal = 0,
        homeAddress: String = "",
        dependents: Int = 0,
        filingStatus: FilingStatus = .single,
        classification: LinemanClassification = .journeymanLineman,
        isCurrent: Bool = false,
        createdAt: Date = .now
    ) {
        self.name = name
        self.ibewLocal = ibewLocal
        self.perDiemRate = perDiemRate
        self.homeAddress = homeAddress
        self.dependents = dependents
        self.filingStatusRaw = filingStatus.rawValue
        self.classificationRaw = classification.rawValue
        self.isCurrent = isCurrent
        self.createdAt = createdAt
    }
}
