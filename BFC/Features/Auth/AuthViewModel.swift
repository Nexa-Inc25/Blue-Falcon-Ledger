import Foundation

/// Drives the login / sign-up screen. Talks to `SessionStore` for the actual auth.
@MainActor
@Observable
final class AuthViewModel {
    enum Mode { case signIn, signUp }

    var mode: Mode = .signIn
    var email = ""
    var password = ""
    var confirmPassword = ""
    var errorMessage: String?
    var isWorking = false

    var title: String { mode == .signIn ? "Sign In" : "Create Account" }
    var actionTitle: String { mode == .signIn ? "Sign In" : "Sign Up" }
    var toggleTitle: String {
        mode == .signIn ? "No account? Sign up" : "Got an account? Sign in"
    }

    func toggleMode() {
        mode = mode == .signIn ? .signUp : .signIn
        errorMessage = nil
    }

    func submit(using session: SessionStore) async {
        errorMessage = nil

        if mode == .signUp, password != confirmPassword {
            errorMessage = "Passwords don't match."
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            switch mode {
            case .signIn:
                try await session.signIn(email: email, password: password)
            case .signUp:
                try await session.signUp(email: email, password: password)
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
