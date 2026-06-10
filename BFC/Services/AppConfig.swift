import Foundation

/// Build-time configuration for the BFC Cloud proxy (the backend that holds the
/// Anthropic key so testers don't need their own). Fill these in after you deploy the
/// proxy in `Proxy/` (see Proxy/README.md), then rebuild.
///
/// Security note: the app token below ships inside the app, so treat it as a throttle,
/// not a secret. Keep rate limiting on the proxy. For production, move to per-user auth.
enum AppConfig {
    /// Base URL of your deployed proxy, e.g. "https://bfc-proxy.yourname.workers.dev".
    /// Leave empty to disable BFC Cloud (the app then falls back to the on-device model).
    static let proxyBaseURL = "https://resilient-gratitude-production-1c3d.up.railway.app"

    /// Shared token the app sends as `Authorization: Bearer <token>`. Must match the
    /// `APP_TOKEN` env var set on the proxy.
    static let proxyAppToken = "GdrRFL0MON1zOasyza6fhYSMYcQEbBPIsezA3pQF839PyfZq"

    /// Whether BFC Cloud is configured and usable.
    static var proxyConfigured: Bool {
        !proxyBaseURL.isEmpty && proxyBaseURL.hasPrefix("https://")
    }
}
