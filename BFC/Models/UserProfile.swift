import Foundation
import SwiftData

/// The signed-in lineman. One per app install (local). Holds the tax context used
/// when reasoning about pay. Auth credentials live in the Keychain, not here.
@Model
final class UserProfile {
    /// Stable id matching the auth account (email or provider uid).
    var accountId: String
    var email: String
    var homeAddress: String
    var dependents: Int
    var filingStatusRaw: String
    var createdAt: Date

    var filingStatus: FilingStatus {
        get { FilingStatus(rawValue: filingStatusRaw) ?? .single }
        set { filingStatusRaw = newValue.rawValue }
    }

    init(
        accountId: String,
        email: String,
        homeAddress: String = "",
        dependents: Int = 0,
        filingStatus: FilingStatus = .single,
        createdAt: Date = .now
    ) {
        self.accountId = accountId
        self.email = email
        self.homeAddress = homeAddress
        self.dependents = dependents
        self.filingStatusRaw = filingStatus.rawValue
        self.createdAt = createdAt
    }
}
