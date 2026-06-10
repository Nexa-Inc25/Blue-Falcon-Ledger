import Foundation

/// Legal URLs required by App Review for auto-renewable subscriptions (Guideline 3.1.2).
/// Host `docs/privacy.html` at the privacy URL before resubmitting.
enum AppLegal {
    /// Apple's standard Licensed Application End User License Agreement.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Privacy policy — hosted on GitHub Pages from `/docs` in this repo.
    static let privacyPolicyURL = URL(string: "https://nexa-inc25.github.io/Blue-Falcon-Ledger/privacy.html")!
}
