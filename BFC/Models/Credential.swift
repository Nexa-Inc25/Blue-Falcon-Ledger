import Foundation
import SwiftData

/// The kind of credential a lineman keeps to sign the books at a hall.
enum CredentialKind: String, Codable, CaseIterable, Identifiable {
    case firstAidCPR = "First Aid / CPR"
    case osha10 = "OSHA 10"
    case letterOfRec = "Letter of Recommendation"
    case dotPhysical = "DOT Physical"
    case duesReceipt = "Union Dues Receipt"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .firstAidCPR: return "cross.case.fill"
        case .osha10: return "checkmark.shield.fill"
        case .letterOfRec: return "envelope.fill"
        case .dotPhysical: return "stethoscope"
        case .duesReceipt: return "dollarsign.circle.fill"
        case .other: return "doc.fill"
        }
    }

    /// Whether this kind typically has an expiration / renewal date (pre-checks the toggle).
    var usuallyExpires: Bool {
        switch self {
        case .firstAidCPR, .dotPhysical, .duesReceipt: return true
        case .osha10, .letterOfRec, .other: return false
        }
    }
}

/// A stored credential document the lineman needs to register for work — with optional
/// expiration tracking and reminders (e.g. CPR card, DOT physical, dues renewal).
@Model
final class Credential {
    var kindRaw: String
    /// Optional custom label; falls back to the kind's name.
    var title: String
    var fileName: String
    /// The uploaded card/document (PDF or image), stored externally.
    @Attribute(.externalStorage) var fileData: Data?
    var issueDate: Date?
    var expirationDate: Date?
    var notes: String
    /// Whether to schedule an expiry reminder. Defaulted for clean migration.
    var reminderEnabled: Bool = true
    /// Stable key used to name this credential's scheduled local notifications, so we can
    /// reschedule/cancel them on edit/delete. Defaulted for clean migration.
    var reminderKey: String = ""
    var createdAt: Date

    init(
        kind: CredentialKind,
        title: String = "",
        fileName: String = "",
        fileData: Data? = nil,
        issueDate: Date? = nil,
        expirationDate: Date? = nil,
        notes: String = "",
        reminderEnabled: Bool = true,
        createdAt: Date = .now
    ) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.fileName = fileName
        self.fileData = fileData
        self.issueDate = issueDate
        self.expirationDate = expirationDate
        self.notes = notes
        self.reminderEnabled = reminderEnabled
        self.reminderKey = UUID().uuidString
        self.createdAt = createdAt
    }

    var kind: CredentialKind {
        get { CredentialKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    /// Display name: custom title if set, else the kind.
    var displayName: String {
        title.trimmingCharacters(in: .whitespaces).isEmpty ? kind.rawValue : title
    }

    var hasFile: Bool { fileData != nil }

    // MARK: Expiration status

    enum Status {
        case noExpiry
        case valid(daysLeft: Int)
        case expiringSoon(daysLeft: Int)
        case expired
    }

    /// Days within which we consider a credential "expiring soon".
    static let soonThresholdDays = 30

    func status(asOf now: Date = .now) -> Status {
        guard let exp = expirationDate else { return .noExpiry }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                      to: cal.startOfDay(for: exp)).day ?? 0
        if days < 0 { return .expired }
        if days <= Self.soonThresholdDays { return .expiringSoon(daysLeft: days) }
        return .valid(daysLeft: days)
    }
}
