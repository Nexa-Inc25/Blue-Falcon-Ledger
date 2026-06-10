import Foundation
import SwiftData

/// A single day worked. Hours are split the way a lineman gets paid: straight time,
/// overtime, and double time. Per diem is tracked per day worked.
@Model
final class WorkDay {
    var date: Date
    var straightHours: Double
    var overtimeHours: Double
    var doubleHours: Double
    /// Whether per diem was received for this day (rate comes from the employer).
    var perDiemReceived: Bool
    /// How many meal periods were missed / not provided this day. Drives meal-penalty
    /// checks against the agreement (many CBAs owe a penalty when you're not fed in time).
    /// Defaulted so existing logged days migrate cleanly when the app updates.
    var mealsMissed: Int = 0
    /// Free-form notes — typed or dictated via voice-to-text.
    var notes: String
    var createdAt: Date

    var employer: Employer?
    /// Set once this day is rolled into a pay period for analysis.
    var payPeriod: PayPeriod?

    var totalHours: Double { straightHours + overtimeHours + doubleHours }

    init(
        date: Date = .now,
        straightHours: Double = 0,
        overtimeHours: Double = 0,
        doubleHours: Double = 0,
        perDiemReceived: Bool = true,
        mealsMissed: Int = 0,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.date = date
        self.straightHours = straightHours
        self.overtimeHours = overtimeHours
        self.doubleHours = doubleHours
        self.perDiemReceived = perDiemReceived
        self.mealsMissed = mealsMissed
        self.notes = notes
        self.createdAt = createdAt
    }
}
