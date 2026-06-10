import Foundation
import CryptoKit

/// Offline auth: credentials are salted-and-hashed and stored in the Keychain. Good
/// enough to ship and demo with zero external setup; swap to Firebase via Settings.
@MainActor
final class LocalAuthService: AuthService {
    static let shared = LocalAuthService()

    private let keychain = KeychainStore.shared
    private let defaults = UserDefaults.standard
    private let currentKey = "auth.current.account"

    private(set) var currentAccount: AuthAccount?

    private init() {
        // Restore session.
        if let id = defaults.string(forKey: currentKey),
           let email = keychain.get(emailKey(for: id)) {
            currentAccount = AuthAccount(id: id, email: email)
        }
    }

    func signUp(email: String, password: String) async throws -> AuthAccount {
        try AuthValidation.validate(email: email, password: password)
        let id = accountId(for: email)
        guard keychain.get(hashKey(for: id)) == nil else { throw AuthError.emailInUse }

        let salt = Self.makeSalt()
        keychain.set(salt, for: saltKey(for: id))
        keychain.set(Self.hash(password: password, salt: salt), for: hashKey(for: id))
        keychain.set(email, for: emailKey(for: id))

        let account = AuthAccount(id: id, email: email)
        setCurrent(account)
        return account
    }

    func signIn(email: String, password: String) async throws -> AuthAccount {
        try AuthValidation.validate(email: email, password: password)
        let id = accountId(for: email)
        guard let storedHash = keychain.get(hashKey(for: id)),
              let salt = keychain.get(saltKey(for: id)) else {
            throw AuthError.wrongCredentials
        }
        guard Self.hash(password: password, salt: salt) == storedHash else {
            throw AuthError.wrongCredentials
        }
        let account = AuthAccount(id: id, email: keychain.get(emailKey(for: id)) ?? email)
        setCurrent(account)
        return account
    }

    func signOut() throws {
        currentAccount = nil
        defaults.removeObject(forKey: currentKey)
    }

    // MARK: - Helpers

    private func setCurrent(_ account: AuthAccount) {
        currentAccount = account
        defaults.set(account.id, forKey: currentKey)
    }

    /// Stable, lowercase-email-derived id (so the same email maps to the same account).
    private func accountId(for email: String) -> String {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        return SHA256.hash(data: Data(normalized.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    private func saltKey(for id: String) -> String { "auth.salt.\(id)" }
    private func hashKey(for id: String) -> String { "auth.hash.\(id)" }
    private func emailKey(for id: String) -> String { "auth.email.\(id)" }

    private static func makeSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func hash(password: String, salt: String) -> String {
        let digest = SHA256.hash(data: Data((salt + password).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
