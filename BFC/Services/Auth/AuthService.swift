import Foundation

/// A signed-in account. Minimal — profile/tax details live in `UserProfile` (SwiftData).
struct AuthAccount: Equatable {
    let id: String
    let email: String
}

enum AuthError: LocalizedError {
    case invalidEmail
    case weakPassword
    case wrongCredentials
    case emailInUse
    case notConfigured
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "That email doesn't look right."
        case .weakPassword: return "Password needs to be at least 6 characters."
        case .wrongCredentials: return "Wrong email or password."
        case .emailInUse: return "There's already an account with that email."
        case .notConfigured: return "Sign-in isn't set up. Check Settings."
        case .underlying(let message): return message
        }
    }
}

/// Auth backend contract. Implementations: `LocalAuthService` (default, offline) and
/// `FirebaseAuthService` (when the Firebase SPM package is added). Main-actor isolated
/// because the concrete services touch shared session state on the main actor.
@MainActor
protocol AuthService: AnyObject {
    var currentAccount: AuthAccount? { get }
    func signUp(email: String, password: String) async throws -> AuthAccount
    func signIn(email: String, password: String) async throws -> AuthAccount
    func signOut() throws
}

/// Shared validation used by every backend.
enum AuthValidation {
    static func validate(email: String, password: String) throws {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("@"), trimmed.contains("."), trimmed.count >= 5 else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 6 else { throw AuthError.weakPassword }
    }
}

/// Picks the configured auth backend. Falls back to local if Firebase isn't compiled in.
enum AuthFactory {
    @MainActor
    static func make(_ backend: AuthBackend) -> AuthService {
        switch backend {
        case .firebase:
            #if canImport(FirebaseAuth)
            return FirebaseAuthService()
            #else
            // Firebase package not added — fall back so the app still works.
            return LocalAuthService.shared
            #endif
        case .local:
            return LocalAuthService.shared
        }
    }
}
