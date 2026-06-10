import Foundation
import SwiftData

/// Logic for the Credentials list: ordering (problems first) and deletion that also
/// clears any scheduled reminder.
@MainActor
@Observable
final class CredentialsViewModel {

    /// Sort so the things that need attention float to the top: expired, then expiring
    /// soon (soonest first), then everything else by name.
    func sorted(_ credentials: [Credential], asOf now: Date = .now) -> [Credential] {
        credentials.sorted { a, b in
            let ra = rank(a, now: now), rb = rank(b, now: now)
            if ra != rb { return ra < rb }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

    private func rank(_ credential: Credential, now: Date) -> Int {
        switch credential.status(asOf: now) {
        case .expired: return 0
        case .expiringSoon: return 1
        case .valid: return 2
        case .noExpiry: return 3
        }
    }

    func delete(_ credential: Credential, context: ModelContext) {
        NotificationService.shared.cancel(key: credential.reminderKey)
        context.delete(credential)
        try? context.save()
    }
}
