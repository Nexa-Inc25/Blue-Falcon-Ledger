import Foundation
import SwiftUI

/// App-wide, non-sensitive preferences (which backends to use). Secrets stay in Keychain.
/// Observable so Settings changes propagate live.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    var authBackend: AuthBackend {
        didSet { defaults.set(authBackend.rawValue, forKey: Keys.authBackend) }
    }

    var llmProvider: LLMProvider {
        didSet { defaults.set(llmProvider.rawValue, forKey: Keys.llmProvider) }
    }

    /// Whether the user has acknowledged the "not legal advice" disclaimer.
    var hasAcceptedDisclaimer: Bool {
        didSet { defaults.set(hasAcceptedDisclaimer, forKey: Keys.disclaimer) }
    }

    /// Free taste of BFC Cloud before Pro is required (lifetime count of metered uses).
    static let freeCloudLimit = 5
    private(set) var cloudUsesConsumed: Int {
        didSet { defaults.set(cloudUsesConsumed, forKey: Keys.cloudUses) }
    }
    var freeCloudUsesRemaining: Int { max(0, Self.freeCloudLimit - cloudUsesConsumed) }
    func consumeFreeCloudUse() { cloudUsesConsumed += 1 }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let authBackend = "authBackend"
        static let llmProvider = "llmProvider"
        static let disclaimer = "hasAcceptedDisclaimer"
        static let cloudUses = "cloudUsesConsumed"
    }

    /// Keychain keys for each provider's API key.
    static func apiKeyKeychainKey(for provider: LLMProvider) -> String {
        "apikey.\(provider.rawValue)"
    }

    private init() {
        let storedAuth = defaults.string(forKey: Keys.authBackend)
        self.authBackend = storedAuth.flatMap(AuthBackend.init) ?? .local

        let storedLLM = defaults.string(forKey: Keys.llmProvider)
        // Default to BFC Cloud (the proxy) so testers get Claude with zero setup. Falls
        // back to the on-device model automatically if the proxy isn't configured yet.
        self.llmProvider = storedLLM.flatMap(LLMProvider.init) ?? .bfcCloud

        self.hasAcceptedDisclaimer = defaults.bool(forKey: Keys.disclaimer)
        self.cloudUsesConsumed = defaults.integer(forKey: Keys.cloudUses)
    }

    /// The standard "not legal advice" copy, reused in the gate and result footers.
    static let disclaimerText = """
    Blue Falcon Ledger helps you read your contract and spot possible pay mistakes. It is NOT legal \
    advice and it can be wrong. Always check anything important against your actual labor \
    agreement and with your local hall or business agent before you act on it — especially \
    before filing a grievance or pay dispute.
    """

    // MARK: API key helpers

    func apiKey(for provider: LLMProvider) -> String? {
        KeychainStore.shared.get(Self.apiKeyKeychainKey(for: provider))
    }

    func setAPIKey(_ key: String, for provider: LLMProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let keychainKey = Self.apiKeyKeychainKey(for: provider)
        if trimmed.isEmpty {
            KeychainStore.shared.delete(keychainKey)
        } else {
            KeychainStore.shared.set(trimmed, for: keychainKey)
        }
    }

    func hasAPIKey(for provider: LLMProvider) -> Bool {
        guard provider.requiresAPIKey else { return true }
        return !(apiKey(for: provider)?.isEmpty ?? true)
    }
}
