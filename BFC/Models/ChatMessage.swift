import Foundation
import SwiftData

/// One message in the chat with the labor-agreement expert. Persisted so the
/// conversation survives app restarts.
@Model
final class ChatMessage {
    var roleRaw: String
    var content: String
    var timestamp: Date
    /// Section headings the answer was drawn from, shown under assistant replies so the
    /// lineman can verify the source. Empty for user messages.
    var sources: [String]

    var agreement: LaborAgreement?

    var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(role: ChatRole, content: String, timestamp: Date = .now, sources: [String] = []) {
        self.roleRaw = role.rawValue
        self.content = content
        self.timestamp = timestamp
        self.sources = sources
    }
}
