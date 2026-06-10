import Foundation
import SwiftUI

/// Owns the auth backend and the signed-in account. Rebuilds the backend when the
/// user switches it in Settings. Injected into the environment.
@MainActor
@Observable
final class SessionStore {
    private(set) var account: AuthAccount?
    var isWorking = false

    private var service: AuthService
    private let settings: AppSettings

    init(settings: AppSettings = .shared) {
        self.settings = settings
        self.service = AuthFactory.make(settings.authBackend)
        self.account = service.currentAccount
    }

    var isSignedIn: Bool { account != nil }

    /// Re-create the auth backend after a Settings change.
    func refreshBackend() {
        service = AuthFactory.make(settings.authBackend)
        account = service.currentAccount
    }

    func signIn(email: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }
        account = try await service.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        isWorking = true
        defer { isWorking = false }
        account = try await service.signUp(email: email, password: password)
    }

    func signOut() {
        try? service.signOut()
        account = nil
    }
}
