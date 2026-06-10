import Foundation

// Real Firebase Auth. This whole file only compiles once the Firebase SPM package is
// added (see CLAUDE.md). Until then the app uses LocalAuthService and this is inert,
// so the project always builds with zero external setup.
#if canImport(FirebaseAuth)
import FirebaseAuth
import FirebaseCore

@MainActor
final class FirebaseAuthService: AuthService {
    init() {
        // Configure Firebase once. Requires GoogleService-Info.plist in the bundle.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var currentAccount: AuthAccount? {
        guard let user = Auth.auth().currentUser else { return nil }
        return AuthAccount(id: user.uid, email: user.email ?? "")
    }

    func signUp(email: String, password: String) async throws -> AuthAccount {
        try AuthValidation.validate(email: email, password: password)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return AuthAccount(id: result.user.uid, email: result.user.email ?? email)
        } catch {
            throw Self.map(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthAccount {
        try AuthValidation.validate(email: email, password: password)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            return AuthAccount(id: result.user.uid, email: result.user.email ?? email)
        } catch {
            throw Self.map(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    private static func map(_ error: Error) -> AuthError {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .emailAlreadyInUse: return .emailInUse
        case .wrongPassword, .invalidCredential, .userNotFound: return .wrongCredentials
        case .weakPassword: return .weakPassword
        case .invalidEmail: return .invalidEmail
        default: return .underlying(error.localizedDescription)
        }
    }
}
#endif
