import Foundation

/// Legal URLs required by App Review for auto-renewable subscriptions (Guideline 3.1.2).
/// Host `docs/privacy.html` at the privacy URL before resubmitting.
enum AppLegal {
    /// Apple's standard Licensed Application End User License Agreement.
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Privacy policy — must be a working page (not a placeholder). Upload `docs/privacy.html`
    /// to your site or GitHub Pages and confirm the URL loads in a browser.
    static let privacyPolicyURL = URL(string: "https://nexa-us.io/privacy.html")!
}
