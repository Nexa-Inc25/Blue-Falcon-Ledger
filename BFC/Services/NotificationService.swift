import Foundation
import UserNotifications

/// Schedules on-device reminders before a credential expires (CPR card, DOT physical,
/// dues renewal). Local notifications only — no server, no push entitlement.
@MainActor
struct NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    /// Days before expiration to fire the heads-up reminder.
    static let leadDays = 30

    /// Ask for permission. Safe to call repeatedly; returns whether we're authorized.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    /// (Re)schedule reminders for a credential. Clears any prior ones first. No-ops if the
    /// credential has no expiration, reminders are off, or permission isn't granted.
    func reschedule(for credential: Credential) async {
        cancel(key: credential.reminderKey)

        guard credential.reminderEnabled, let expiration = credential.expirationDate else { return }
        guard await requestAuthorization() else { return }

        let cal = Calendar.current
        let name = credential.displayName

        // Heads-up reminder N days before expiry (only if that's still in the future).
        if let lead = cal.date(byAdding: .day, value: -Self.leadDays, to: expiration), lead > .now {
            schedule(id: "\(credential.reminderKey).lead", at: lead,
                     title: "\(name) expires soon",
                     body: "Your \(credential.kind.rawValue) expires \(expiration.formatted(date: .abbreviated, time: .omitted)). Renew it before you sign the books.")
        }

        // Day-of reminder (only if the expiration itself is in the future).
        if expiration > .now {
            schedule(id: "\(credential.reminderKey).expiry", at: expiration,
                     title: "\(name) expires today",
                     body: "Your \(credential.kind.rawValue) expires today. Get it renewed.")
        }
    }

    /// Cancel all reminders for a credential's key.
    func cancel(key: String) {
        guard !key.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ["\(key).lead", "\(key).expiry"])
    }

    // MARK: - Private

    private func schedule(id: String, at date: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Fire at ~9am local on the target day.
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
